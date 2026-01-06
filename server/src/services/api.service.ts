import { Injectable } from '@nestjs/common';
import { Interval } from '@nestjs/schedule';
import { NextFunction, Request, Response } from 'express';
import { readFileSync } from 'node:fs';
import sanitizeHtml from 'sanitize-html';
import { ONE_HOUR } from 'src/constants';
import { ConfigRepository } from 'src/repositories/config.repository';
import { LoggingRepository } from 'src/repositories/logging.repository';
import { AuthService } from 'src/services/auth.service';
import { SharedLinkService } from 'src/services/shared-link.service';
import { VersionService } from 'src/services/version.service';
import { OpenGraphTags } from 'src/utils/misc';

export const render = (index: string, meta: OpenGraphTags) => {
  const [title, description, imageUrl] = [meta.title, meta.description, meta.imageUrl].map((item) =>
    item ? sanitizeHtml(item, { allowedTags: [] }) : '',
  );

  const tags = `
    <meta name="description" content="${description}" />

    <!-- Facebook Meta Tags -->
    <meta property="og:type" content="website" />
    <meta property="og:title" content="${title}" />
    <meta property="og:description" content="${description}" />
    ${imageUrl ? `<meta property="og:image" content="${imageUrl}" />` : ''}

    <!-- Twitter Meta Tags -->
    <meta name="twitter:card" content="summary_large_image" />
    <meta name="twitter:title" content="${title}" />
    <meta name="twitter:description" content="${description}" />

    ${imageUrl ? `<meta name="twitter:image" content="${imageUrl}" />` : ''}`;

  return index.replace('<!-- metadata:tags -->', tags);
};

function isIPv4(ip: string): boolean {
  // 拆分成四段
  const parts = ip.split('.');
  if (parts.length !== 4) {
    return false;
  }

  for (const part of parts) {
    // 每段不能为空，且只能包含 0–9 数字
    if (!/^\d+$/.test(part)) {
      return false;
    }

    // 转成数字，看是否在 0–255 范围内
    const num = Number(part);
    if (num < 0 || num > 255) {
      return false;
    }

    // 防止 “01”、“001” 这种前导零的非标准写法（可选）
    // 如果你允许 “01” 这种写法，可以把下面这一段注释掉
    if (part.length > 1 && part.startsWith('0')) {
      return false;
    }
  }

  return true;
}

function isPrivateIp(ip?: string): boolean {
  if (!ip) return false;
  // 如果有 ipv4-mapped IPv6 前缀，先拆掉
  if (ip.startsWith('::ffff:')) {
    ip = ip.replace('::ffff:', '');
  }
  if (!isIPv4(ip)) return false;
  const [a, b] = ip.split('.').map((n) => parseInt(n, 10));
  // 10.0.0.0/8
  if (a === 10) return true;
  // 172.16.0.0/12
  if (a === 172 && b >= 16 && b <= 31) return true;
  // 192.168.0.0/16
  if (a === 192 && b === 168) return true;
  // localhost
  if (ip === '127.0.0.1') return true;
  return false;
}

@Injectable()
export class ApiService {
  constructor(
    private authService: AuthService,
    private sharedLinkService: SharedLinkService,
    private versionService: VersionService,
    private configRepository: ConfigRepository,
    private logger: LoggingRepository,
  ) {
    this.logger.setContext(ApiService.name);
  }

  @Interval(ONE_HOUR.as('milliseconds'))
  async onVersionCheck() {
    await this.versionService.handleQueueVersionCheck();
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
      
      const forwarded = request.headers['x-forwarded-for'];
      const realIp = request.headers['x-real-ip'];
      const ip =
        (typeof realIp === 'string' && realIp) ||
        (typeof forwarded === 'string' && forwarded.split(',')[0].trim()) || request.ip;
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

      res.status(status).type('text/html').header('Cache-Control', 'no-store').send(html);
    };
  }
}
