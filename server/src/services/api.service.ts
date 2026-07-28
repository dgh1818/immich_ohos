import { Injectable, NotAcceptableException } from '@nestjs/common';
import { NextFunction, Request, Response } from 'express';
import { escape } from 'lodash';
import { readFileSync } from 'node:fs';
import { isIP } from 'node:net';
import { ConfigRepository } from 'src/repositories/config.repository';
import { LoggingRepository } from 'src/repositories/logging.repository';
import { AuthService } from 'src/services/auth.service';
import { SharedLinkService } from 'src/services/shared-link.service';
import { OpenGraphTags } from 'src/utils/misc';

export const render = (index: string, meta: OpenGraphTags) => {
  const [title, description, imageUrl] = [meta.title, meta.description, meta.imageUrl].map((item) =>
    item ? escape(item) : '',
  );

  const tags = `
    <meta name="description" content="${description}" />

    <!-- Facebook Meta Tags -->
    <meta property="og:type" content="website" />
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    ${imageUrl ? `<meta property="og:image" content="${imageUrl}" />` : ''}`;

  return index.replace('<!-- metadata:tags -->', () => tags);
};

function normalizeIp(ip?: string): string | undefined {
  let normalized = ip?.trim();
  if (!normalized) {
    return undefined;
  }

  const bracketMatch = normalized.match(/^\[([^[\]]+)\](?::\d+)?$/);
  if (bracketMatch) {
    normalized = bracketMatch[1];
  }

  const ipv4WithPortMatch = normalized.match(/^(\d{1,3}(?:\.\d{1,3}){3}):\d+$/);
  if (ipv4WithPortMatch) {
    normalized = ipv4WithPortMatch[1];
  }

  const zoneIndex = normalized.indexOf('%');
  if (zoneIndex !== -1) {
    normalized = normalized.slice(0, zoneIndex);
  }

  return normalized.toLowerCase();
}

function getHeaderIp(value: string | string[] | undefined): string | undefined {
  if (Array.isArray(value)) {
    value = value[0];
  }

  return normalizeIp(value?.split(',')[0]);
}

function isPrivateIpv4(ip: string): boolean {
  const parts = ip.split('.');
  if (parts.length !== 4 || parts.some((part) => !/^\d+$/.test(part))) {
    return false;
  }

  const [a, b] = parts.map((part) => Number(part));

  if (a === 10) return true;
  if (a === 172 && b >= 16 && b <= 31) return true;
  if (a === 192 && b === 168) return true;
  if (ip === '127.0.0.1') return true;
  return false;
}

function isPrivateIpv6(ip: string): boolean {
  if (ip === '::1' || ip === '::') {
    return true;
  }

  const firstHextet = ip.split(':')[0];
  if (firstHextet.startsWith('fc') || firstHextet.startsWith('fd')) {
    return true;
  }

  if (/^fe[89ab]/.test(firstHextet)) {
    return true;
  }

  return false;
}

function getClientIp(request: Request): string | undefined {
  return getHeaderIp(request.headers['x-forwarded-for']) || normalizeIp(request.ip);
}

function isPrivateIp(ip?: string): boolean {
  const normalized = normalizeIp(ip);
  if (!normalized) {
    return false;
  }

  if (normalized.startsWith('::ffff:')) {
    return isPrivateIp(normalized.slice('::ffff:'.length));
  }

  const version = isIP(normalized);
  if (version === 4) {
    return isPrivateIpv4(normalized);
  }

  if (version === 6) {
    return isPrivateIpv6(normalized);
  }

  return false;
}

@Injectable()
export class ApiService {
  constructor(
    private authService: AuthService,
    private sharedLinkService: SharedLinkService,
    private configRepository: ConfigRepository,
    private logger: LoggingRepository,
  ) {
    this.logger.setContext(ApiService.name);
  }

  ssr(excludePaths: string[]) {
    const { resourcePaths } = this.configRepository.getEnv();

    let index = '';
    try {
      index = readFileSync(resourcePaths.web.indexHtml).toString();
    } catch {
      this.logger.warn(`Unable to open ${resourcePaths.web.indexHtml}, skipping SSR.`);
    }

    return async (request: Request, res: Response, next: NextFunction) => {
      const method = request.method.toLowerCase();
      const ip = getClientIp(request);
      if (
        request.url.startsWith('/api') ||
        (method !== 'get' && method !== 'head') ||
        excludePaths.some((item) => request.url.startsWith(item))
      ) {
        return next();
      }

      if (process.env.FORBIDDEN_WEB_FROM_INTERNET === 'true') {
        if (!isPrivateIp(ip)) {
          return res.sendStatus(404);
        }
      }

      const responseType = request.accepts('text/html');
      if (!responseType) {
        throw new NotAcceptableException(
          `The route ${request.path} was requested as ${request.header('accept')}, but only returns text/html`,
        );
      }

      let status = 200;
      let html = index;

      const defaultDomain = request.host ? `${request.protocol}://${request.host}` : undefined;

      let meta: OpenGraphTags | null = null;

      const shareKey = request.url.match(/^\/share\/(.+)$/);
      if (shareKey) {
        try {
          const key = shareKey[1];
          const auth = await this.authService.validateSharedLinkKey(key);
          meta = await this.sharedLinkService.getMetadataTags(auth, defaultDomain);
        } catch {
          status = 404;
        }
      }

      const shareSlug = request.url.match(/^\/s\/(.+)$/);
      if (shareSlug) {
        try {
          const slug = shareSlug[1];
          const auth = await this.authService.validateSharedLinkSlug(slug);
          meta = await this.sharedLinkService.getMetadataTags(auth, defaultDomain);
        } catch {
          status = 404;
        }
      }

      if (meta) {
        html = render(index, meta);
      }

      res.status(status).type(responseType).header('Cache-Control', 'no-store').send(html);
    };
  }
}
