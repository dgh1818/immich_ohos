import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { uri } from '@kit.ArkTS';
import bundleManager from '@ohos.bundle.bundleManager';
import fs from '@ohos.file.fs';
import util from '@ohos.util';

export interface StoredClientCert {
  certPath: string;
  keyPath: string;
  certType: http.CertType;
  keyPassword?: string;
}

interface StoredRequestState {
  headers: Record<string, string>;
  serverUrls: string[];
}

interface StoredCookie {
  name: string;
  value: string;
  domain: string;
  path: string;
  expiresAt?: number;
  secure: boolean;
  httpOnly: boolean;
}

interface ParsedServerUrl {
  host: string;
  secure: boolean;
}

interface ParsedRequestUrl {
  host: string;
  path: string;
  secure: boolean;
}

export class URLSessionManager {
  private static readonly BUNDLE_INFO_FLAGS = bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION;
  private static readonly PREF_NAME = 'Immich::ClientCert';
  private static readonly KEY_CERT_PATH = 'certPath';
  private static readonly KEY_KEY_PATH = 'keyPath';
  private static readonly KEY_CERT_TYPE = 'certType';
  private static readonly KEY_KEY_PASSWORD = 'keyPassword';
  private static readonly KEY_HEADERS = 'requestHeaders';
  private static readonly KEY_SERVER_URLS = 'serverUrls';
  private static readonly KEY_COOKIES = 'cookies';
  private static readonly LEGACY_KEY_TOKEN = 'authToken';
  private static readonly LEGACY_KEY_AUTH_COOKIE = 'authCookie';
  private static readonly ACCESS_TOKEN_COOKIE = 'immich_access_token';
  private static readonly IS_AUTHENTICATED_COOKIE = 'immich_is_authenticated';
  private static readonly AUTH_TYPE_COOKIE = 'immich_auth_type';
  private static readonly COOKIE_EXPIRY_DAYS = 400;
  private static readonly USER_AGENT = URLSessionManager.buildUserAgent();
  private static readonly AUTH_COOKIE_NAMES = new Set<string>([
    URLSessionManager.ACCESS_TOKEN_COOKIE,
    URLSessionManager.IS_AUTHENTICATED_COOKIE,
    URLSessionManager.AUTH_TYPE_COOKIE,
  ]);

  private static cached: StoredClientCert | null = null;
  private static loaded = false;
  private static cachedRequestState: StoredRequestState = { headers: {}, serverUrls: [] };
  private static requestStateLoaded = false;
  private static cachedCookies: StoredCookie[] = [];
  private static cookiesLoaded = false;

  static applyToOptions(
    context: common.Context | undefined,
    options: http.HttpRequestOptions,
    requestUrl?: string
  ): void {
    if (!context) {
      return;
    }

    const requestState = URLSessionManager.loadRequestState(context);
    const mergedHeaders = URLSessionManager.toHeaderRecord(options.header);
    Object.keys(requestState.headers).forEach((key) => {
      if (mergedHeaders[key] === undefined) {
        mergedHeaders[key] = requestState.headers[key];
      }
    });
    if (mergedHeaders['User-Agent'] === undefined && mergedHeaders['user-agent'] === undefined) {
      mergedHeaders['User-Agent'] = URLSessionManager.USER_AGENT;
    }

    const effectiveHeaders = requestUrl
      ? URLSessionManager.applyCookieHeaders(
          mergedHeaders,
          URLSessionManager.loadCookies(context),
          requestUrl
        )
      : mergedHeaders;

    if (Object.keys(effectiveHeaders).length > 0) {
      options.header = effectiveHeaders;
    }

    const cert = URLSessionManager.load(context);
    if (!cert) {
      return;
    }
    const clientCert: http.ClientCert = {
      certPath: cert.certPath,
      certType: cert.certType,
      keyPath: cert.keyPath,
    };
    if (cert.keyPassword && cert.keyPassword.length > 0) {
      clientCert.keyPassword = cert.keyPassword;
    }
    options.clientCert = clientCert;
  }

  static updateFromResponse(context: common.Context | undefined, requestUrl: string, headerObj?: Object): void {
    if (!context || !headerObj) {
      return;
    }

    const setCookieValues = URLSessionManager.extractHeaderValues(headerObj, 'set-cookie');
    if (setCookieValues.length === 0) {
      return;
    }

    const cookies = URLSessionManager.loadCookies(context).slice();
    setCookieValues.forEach((value) => {
      const parsed = URLSessionManager.parseSetCookie(requestUrl, value);
      if (!parsed) {
        return;
      }

      const existingIndex = cookies.findIndex((cookie) =>
        cookie.name === parsed.name &&
        cookie.domain === parsed.domain &&
        cookie.path === parsed.path
      );
      if (existingIndex >= 0) {
        cookies.splice(existingIndex, 1);
      }
      if (!URLSessionManager.isExpiredCookie(parsed) && parsed.value.length > 0) {
        cookies.push(parsed);
      }
    });

    const syncedCookies = URLSessionManager.syncAuthCookies(
      URLSessionManager.removeExpiredCookies(cookies),
      URLSessionManager.loadRequestState(context).serverUrls
    );
    URLSessionManager.persistCookies(context, syncedCookies);
  }

  static hasCertificate(context: common.Context): boolean {
    return URLSessionManager.load(context) !== null;
  }

  static setRequestHeaders(
    context: common.Context,
    headers: Map<string, string>,
    serverUrls: string[],
    token?: string | null
  ): void {
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const headerRecord = URLSessionManager.toHeaderRecord(headers);
    pref.putSync(URLSessionManager.KEY_HEADERS, JSON.stringify(headerRecord));
    pref.putSync(URLSessionManager.KEY_SERVER_URLS, JSON.stringify(serverUrls));
    pref.deleteSync(URLSessionManager.LEGACY_KEY_TOKEN);
    pref.deleteSync(URLSessionManager.LEGACY_KEY_AUTH_COOKIE);
    pref.flushSync();

    URLSessionManager.cachedRequestState = {
      headers: headerRecord,
      serverUrls: Array.from(serverUrls),
    };
    URLSessionManager.requestStateLoaded = true;

    let cookies = URLSessionManager.syncAuthCookies(URLSessionManager.loadCookies(context), serverUrls);
    if (token !== undefined && token !== null && token.length > 0) {
      cookies = URLSessionManager.mergeCookies(cookies, URLSessionManager.createAuthCookies(serverUrls, token));
    }
    URLSessionManager.persistCookies(context, cookies);
  }

  static load(context: common.Context): StoredClientCert | null {
    if (URLSessionManager.loaded) {
      return URLSessionManager.cached;
    }
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const certPath = pref.getSync(URLSessionManager.KEY_CERT_PATH, '') as string;
    const keyPath = pref.getSync(URLSessionManager.KEY_KEY_PATH, '') as string;
    if (!certPath || !keyPath) {
      URLSessionManager.cached = null;
      URLSessionManager.loaded = true;
      return null;
    }
    if (!URLSessionManager.safeAccess(certPath)) {
      URLSessionManager.clear(context);
      URLSessionManager.cached = null;
      URLSessionManager.loaded = true;
      return null;
    }
    const certTypeRaw = pref.getSync(URLSessionManager.KEY_CERT_TYPE, 'P12') as string;
    const keyPassword = pref.getSync(URLSessionManager.KEY_KEY_PASSWORD, '') as string;
    URLSessionManager.cached = {
      certPath: certPath,
      keyPath: keyPath,
      certType: URLSessionManager.parseCertType(certTypeRaw),
      keyPassword: keyPassword.length > 0 ? keyPassword : undefined,
    };
    URLSessionManager.loaded = true;
    return URLSessionManager.cached;
  }

  static saveFromBytes(
    context: common.Context,
    data: Uint8Array,
    password?: string,
    extension?: string
  ): StoredClientCert {
    const ext = URLSessionManager.normalizeExtension(extension);
    const certType = http.CertType.P12;
    const certPath = URLSessionManager.writeCertFile(context, data, ext);
    const keyPath = certPath;
    const record: StoredClientCert = {
      certPath,
      keyPath,
      certType,
      keyPassword: password && password.length > 0 ? password : undefined,
    };
    return URLSessionManager.save(context, record);
  }

  static save(context: common.Context, cert: StoredClientCert): StoredClientCert {
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    pref.putSync(URLSessionManager.KEY_CERT_PATH, cert.certPath);
    pref.putSync(URLSessionManager.KEY_KEY_PATH, cert.keyPath);
    pref.putSync(URLSessionManager.KEY_CERT_TYPE, cert.certType as string);
    pref.putSync(URLSessionManager.KEY_KEY_PASSWORD, cert.keyPassword ?? '');
    pref.flushSync();
    URLSessionManager.cached = cert;
    URLSessionManager.loaded = true;
    return cert;
  }

  static clear(context: common.Context): void {
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const certPath = pref.getSync(URLSessionManager.KEY_CERT_PATH, '') as string;
    const keyPath = pref.getSync(URLSessionManager.KEY_KEY_PATH, '') as string;
    if (certPath && URLSessionManager.safeAccess(certPath)) {
      try {
        fs.unlinkSync(certPath);
      } catch (_) {
        // ignore delete errors
      }
    }
    if (keyPath && keyPath !== certPath && URLSessionManager.safeAccess(keyPath)) {
      try {
        fs.unlinkSync(keyPath);
      } catch (_) {
        // ignore delete errors
      }
    }
    pref.deleteSync(URLSessionManager.KEY_CERT_PATH);
    pref.deleteSync(URLSessionManager.KEY_KEY_PATH);
    pref.deleteSync(URLSessionManager.KEY_CERT_TYPE);
    pref.deleteSync(URLSessionManager.KEY_KEY_PASSWORD);
    pref.flushSync();
    URLSessionManager.cached = null;
    URLSessionManager.loaded = true;
  }

  static readBytes(path: string): Uint8Array {
    const stat = fs.statSync(path);
    const file = fs.openSync(path, fs.OpenMode.READ_ONLY);
    try {
      const buffer = new ArrayBuffer(stat.size);
      fs.readSync(file.fd, buffer);
      return new Uint8Array(buffer);
    } finally {
      fs.closeSync(file);
    }
  }

  private static writeCertFile(context: common.Context, data: Uint8Array, extension: string): string {
    const baseDir = `${context.filesDir}/ssl_client_cert`;
    if (!URLSessionManager.safeAccess(baseDir)) {
      fs.mkdirSync(baseDir, true);
    }
    const fileName = `client_cert.${extension}`;
    const certPath = `${baseDir}/${fileName}`;
    const file = fs.openSync(certPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
    try {
      fs.truncateSync(file.fd, 0);
      const buffer = data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength);
      fs.writeSync(file.fd, buffer);
      fs.truncateSync(file.fd, data.byteLength);
    } finally {
      fs.closeSync(file);
    }
    return certPath;
  }

  private static loadRequestState(context: common.Context): StoredRequestState {
    if (URLSessionManager.requestStateLoaded) {
      return URLSessionManager.cachedRequestState;
    }

    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const headersJson = pref.getSync(URLSessionManager.KEY_HEADERS, '') as string;
    const serverUrlsJson = pref.getSync(URLSessionManager.KEY_SERVER_URLS, '') as string;

    let headers: Record<string, string> = {};
    if (headersJson) {
      try {
        headers = URLSessionManager.toHeaderRecord(JSON.parse(headersJson) as Object);
      } catch (_) {
        headers = {};
      }
    }

    let serverUrls: string[] = [];
    if (serverUrlsJson) {
      try {
        const parsed = JSON.parse(serverUrlsJson) as Array<string>;
        serverUrls = parsed.filter((value) => value != null && value.length > 0);
      } catch (_) {
        serverUrls = [];
      }
    }

    URLSessionManager.cachedRequestState = {
      headers,
      serverUrls,
    };
    URLSessionManager.requestStateLoaded = true;
    return URLSessionManager.cachedRequestState;
  }

  private static loadCookies(context: common.Context): StoredCookie[] {
    if (URLSessionManager.cookiesLoaded) {
      return URLSessionManager.cachedCookies;
    }

    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const cookiesJson = pref.getSync(URLSessionManager.KEY_COOKIES, '') as string;
    let cookies: StoredCookie[] = [];

    if (cookiesJson) {
      try {
        const parsed = JSON.parse(cookiesJson) as Array<StoredCookie>;
        cookies = URLSessionManager.removeExpiredCookies(parsed);
      } catch (_) {
        cookies = [];
      }
    } else {
      cookies = URLSessionManager.migrateLegacyCookies(context, pref);
    }

    URLSessionManager.cachedCookies = cookies;
    URLSessionManager.cookiesLoaded = true;
    return URLSessionManager.cachedCookies;
  }

  private static migrateLegacyCookies(
    context: common.Context,
    pref: preferences.Preferences
  ): StoredCookie[] {
    const requestState = URLSessionManager.loadRequestState(context);
    const legacyToken = pref.getSync(URLSessionManager.LEGACY_KEY_TOKEN, '') as string;
    if (legacyToken.length > 0) {
      const cookies = URLSessionManager.createAuthCookies(requestState.serverUrls, legacyToken);
      URLSessionManager.persistCookies(context, cookies);
      return cookies;
    }

    const legacyAuthCookie = pref.getSync(URLSessionManager.LEGACY_KEY_AUTH_COOKIE, '') as string;
    if (legacyAuthCookie.length > 0) {
      const token = URLSessionManager.extractLegacyToken(legacyAuthCookie);
      const cookies = token ? URLSessionManager.createAuthCookies(requestState.serverUrls, token) : [];
      URLSessionManager.persistCookies(context, cookies);
      return cookies;
    }

    return [];
  }

  private static persistCookies(context: common.Context, cookies: StoredCookie[]): void {
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    pref.putSync(URLSessionManager.KEY_COOKIES, JSON.stringify(cookies));
    pref.deleteSync(URLSessionManager.LEGACY_KEY_TOKEN);
    pref.deleteSync(URLSessionManager.LEGACY_KEY_AUTH_COOKIE);
    pref.flushSync();
    URLSessionManager.cachedCookies = cookies;
    URLSessionManager.cookiesLoaded = true;
  }

  private static applyCookieHeaders(
    headers: Record<string, string>,
    cookies: StoredCookie[],
    requestUrl: string
  ): Record<string, string> {
    let effectiveHeaders = headers;
    const cookie = URLSessionManager.buildCookieHeader(cookies, requestUrl);
    if (cookie) {
      const existingCookie = headers['Cookie'] ?? headers['cookie'];
      effectiveHeaders = URLSessionManager.copyHeadersWithout(headers, 'cookie');
      effectiveHeaders['Cookie'] = existingCookie && existingCookie.length > 0
        ? `${existingCookie}; ${cookie}`
        : cookie;
    }

    if (effectiveHeaders['Authorization'] !== undefined || effectiveHeaders['authorization'] !== undefined) {
      return effectiveHeaders;
    }

    const basicAuth = URLSessionManager.buildBasicAuthorization(requestUrl);
    if (basicAuth) {
      effectiveHeaders['Authorization'] = basicAuth;
    }

    return effectiveHeaders;
  }

  private static buildCookieHeader(cookies: StoredCookie[], requestUrl: string): string | undefined {
    const parsed = URLSessionManager.parseRequestUrl(requestUrl);
    if (!parsed) {
      return undefined;
    }

    const now = Date.now();
    const matches = cookies.filter((cookie) =>
      !URLSessionManager.isExpiredCookie(cookie, now) &&
      URLSessionManager.domainMatches(parsed.host, cookie.domain) &&
      URLSessionManager.pathMatches(parsed.path, cookie.path) &&
      (!cookie.secure || parsed.secure)
    );
    if (matches.length === 0) {
      return undefined;
    }

    return matches.map((cookie) => `${cookie.name}=${cookie.value}`).join('; ');
  }

  private static mergeCookies(cookies: StoredCookie[], incoming: StoredCookie[]): StoredCookie[] {
    const merged = cookies.slice();
    incoming.forEach((cookie) => {
      const index = merged.findIndex((existing) =>
        existing.name === cookie.name &&
        existing.domain === cookie.domain &&
        existing.path === cookie.path
      );
      if (index >= 0) {
        merged.splice(index, 1);
      }
      merged.push(cookie);
    });
    return URLSessionManager.removeExpiredCookies(merged);
  }

  private static syncAuthCookies(cookies: StoredCookie[], serverUrls: string[]): StoredCookie[] {
    const parsedServerUrls: ParsedServerUrl[] = [];
    serverUrls.forEach((serverUrl) => {
      const parsed = URLSessionManager.parseServerUrl(serverUrl);
      if (parsed) {
        parsedServerUrls.push(parsed);
      }
    });
    if (parsedServerUrls.length === 0) {
      return cookies;
    }

    const serverHosts = new Set<string>(parsedServerUrls.map((serverUrl) => serverUrl.host));
    const now = Date.now();
    const sourceCookies = new Map<string, StoredCookie>();
    cookies.forEach((cookie) => {
      if (
        URLSessionManager.AUTH_COOKIE_NAMES.has(cookie.name) &&
        serverHosts.has(cookie.domain) &&
        !URLSessionManager.isExpiredCookie(cookie, now)
      ) {
        sourceCookies.set(cookie.name, cookie);
      }
    });

    const filteredCookies = cookies.filter((cookie) =>
      !(URLSessionManager.AUTH_COOKIE_NAMES.has(cookie.name) && serverHosts.has(cookie.domain))
    );

    if (sourceCookies.size === 0) {
      return filteredCookies;
    }

    parsedServerUrls.forEach((serverUrl) => {
      sourceCookies.forEach((cookie) => {
        filteredCookies.push({
          name: cookie.name,
          value: cookie.value,
          domain: serverUrl.host,
          path: '/',
          expiresAt: cookie.expiresAt,
          secure: serverUrl.secure,
          httpOnly: cookie.httpOnly,
        });
      });
    });

    return filteredCookies;
  }

  private static createAuthCookies(serverUrls: string[], token: string): StoredCookie[] {
    const expiry = Date.now() + URLSessionManager.COOKIE_EXPIRY_DAYS * 24 * 60 * 60 * 1000;
    const authCookies: StoredCookie[] = [];

    serverUrls.forEach((serverUrl) => {
      const parsed = URLSessionManager.parseServerUrl(serverUrl);
      if (!parsed) {
        return;
      }

      authCookies.push({
        name: URLSessionManager.ACCESS_TOKEN_COOKIE,
        value: token,
        domain: parsed.host,
        path: '/',
        expiresAt: expiry,
        secure: parsed.secure,
        httpOnly: true,
      });
      authCookies.push({
        name: URLSessionManager.IS_AUTHENTICATED_COOKIE,
        value: 'true',
        domain: parsed.host,
        path: '/',
        expiresAt: expiry,
        secure: parsed.secure,
        httpOnly: false,
      });
      authCookies.push({
        name: URLSessionManager.AUTH_TYPE_COOKIE,
        value: 'password',
        domain: parsed.host,
        path: '/',
        expiresAt: expiry,
        secure: parsed.secure,
        httpOnly: true,
      });
    });

    return authCookies;
  }

  private static extractHeaderValues(headers: Object, targetHeader: string): string[] {
    const values: string[] = [];
    const target = targetHeader.toLowerCase();

    const addValue = (value: Object) => {
      if (value === undefined || value === null) {
        return;
      }

      if (value instanceof Array) {
        value.forEach((entry: Object) => {
          if (entry !== undefined && entry !== null) {
            values.push(`${entry}`);
          }
        });
        return;
      }

      values.push(`${value}`);
    };

    if (headers instanceof Map) {
      headers.forEach((value: Object, key: string) => {
        if (key && key.toLowerCase() === target) {
          addValue(value);
        }
      });
      return values;
    }

    const record = headers as Record<string, Object>;
    Object.keys(record).forEach((key) => {
      if (key.toLowerCase() === target) {
        addValue(record[key]);
      }
    });
    return values;
  }

  private static parseSetCookie(requestUrl: string, rawValue: string): StoredCookie | undefined {
    const request = URLSessionManager.parseRequestUrl(requestUrl);
    if (!request) {
      return undefined;
    }

    const parts = rawValue.split(';');
    if (parts.length === 0) {
      return undefined;
    }

    const nameValue = parts[0].trim();
    const separatorIndex = nameValue.indexOf('=');
    if (separatorIndex <= 0) {
      return undefined;
    }

    const cookie: StoredCookie = {
      name: nameValue.substring(0, separatorIndex).trim(),
      value: nameValue.substring(separatorIndex + 1).trim(),
      domain: request.host,
      path: '/',
      secure: false,
      httpOnly: false,
    };

    for (let index = 1; index < parts.length; index++) {
      const rawPart = parts[index].trim();
      if (rawPart.length === 0) {
        continue;
      }

      const lowerPart = rawPart.toLowerCase();
      if (lowerPart === 'secure') {
        cookie.secure = true;
        continue;
      }
      if (lowerPart === 'httponly') {
        cookie.httpOnly = true;
        continue;
      }

      const attributeSeparator = rawPart.indexOf('=');
      if (attributeSeparator <= 0) {
        continue;
      }

      const attributeName = rawPart.substring(0, attributeSeparator).trim().toLowerCase();
      const attributeValue = rawPart.substring(attributeSeparator + 1).trim();
      switch (attributeName) {
        case 'domain':
          cookie.domain = attributeValue.startsWith('.') ? attributeValue.substring(1) : attributeValue;
          break;
        case 'path':
          cookie.path = attributeValue.length > 0 ? attributeValue : '/';
          break;
        case 'max-age': {
          const maxAge = Number(attributeValue);
          if (!Number.isNaN(maxAge)) {
            cookie.expiresAt = Date.now() + maxAge * 1000;
          }
          break;
        }
        case 'expires': {
          const expiresAt = Date.parse(attributeValue);
          if (!Number.isNaN(expiresAt)) {
            cookie.expiresAt = expiresAt;
          }
          break;
        }
      }
    }

    return cookie;
  }

  private static extractLegacyToken(cookieHeader: string): string | undefined {
    const cookies = cookieHeader.split(';');
    for (let index = 0; index < cookies.length; index++) {
      const value = cookies[index].trim();
      if (value.startsWith(`${URLSessionManager.ACCESS_TOKEN_COOKIE}=`)) {
        return value.substring(URLSessionManager.ACCESS_TOKEN_COOKIE.length + 1);
      }
    }
    return undefined;
  }

  private static parseRequestUrl(
    rawUrl: string
  ): ParsedRequestUrl | undefined {
    try {
      const parsed = new uri.URI(rawUrl);
      return {
        host: parsed.host,
        path: parsed.path.length > 0 ? parsed.path : '/',
        secure: parsed.scheme.toLowerCase() === 'https',
      };
    } catch (_) {
      return undefined;
    }
  }

  private static parseServerUrl(rawUrl: string): ParsedServerUrl | undefined {
    try {
      const parsed = new uri.URI(rawUrl);
      return {
        host: parsed.host,
        secure: parsed.scheme.toLowerCase() === 'https',
      };
    } catch (_) {
      return undefined;
    }
  }

  private static removeExpiredCookies(cookies: StoredCookie[]): StoredCookie[] {
    const now = Date.now();
    return cookies.filter((cookie) => !URLSessionManager.isExpiredCookie(cookie, now));
  }

  private static isExpiredCookie(cookie: StoredCookie, now: number = Date.now()): boolean {
    return cookie.expiresAt !== undefined && cookie.expiresAt <= now;
  }

  private static domainMatches(host: string, domain: string): boolean {
    return host === domain || host.endsWith(`.${domain}`);
  }

  private static pathMatches(requestPath: string, cookiePath: string): boolean {
    return requestPath === cookiePath || requestPath.startsWith(cookiePath.endsWith('/') ? cookiePath : `${cookiePath}/`);
  }

  private static copyHeadersWithout(
    headers: Record<string, string>,
    excludedKey: string
  ): Record<string, string> {
    const copiedHeaders: Record<string, string> = {};
    Object.keys(headers).forEach((key) => {
      if (key !== excludedKey) {
        copiedHeaders[key] = headers[key];
      }
    });
    return copiedHeaders;
  }

  private static buildBasicAuthorization(requestUrl: string): string | undefined {
    try {
      const parsed = new uri.URI(requestUrl);
      const userInfo = parsed.userInfo;
      if (!userInfo || userInfo.length === 0) {
        return undefined;
      }

      const credentials = new util.TextEncoder().encodeInto(userInfo);
      const encoded = new util.Base64Helper().encodeToStringSync(credentials);
      return `Basic ${encoded}`;
    } catch (_) {
      return undefined;
    }
  }

  private static toHeaderRecord(headers?: Object): Record<string, string> {
    const out: Record<string, string> = {};
    if (!headers) {
      return out;
    }

    if (headers instanceof Map) {
      headers.forEach((value: string, key: string) => {
        if (key) {
          out[key] = value ?? '';
        }
      });
      return out;
    }

    Object.keys(headers as Record<string, Object>).forEach((key) => {
      const value = (headers as Record<string, Object>)[key];
      if (value !== undefined && value !== null) {
        out[key] = `${value}`;
      }
    });
    return out;
  }

  private static buildUserAgent(): string {
    try {
      const bundleInfo = bundleManager.getBundleInfoForSelfSync(URLSessionManager.BUNDLE_INFO_FLAGS);
      const version = bundleInfo.versionName && bundleInfo.versionName.length > 0
        ? bundleInfo.versionName
        : 'unknown';
      return `immich-ohos/${version}`;
    } catch (_) {
      return 'immich-ohos/unknown';
    }
  }

  private static normalizeExtension(extension?: string): string {
    if (!extension) {
      return 'p12';
    }
    const cleaned = extension.trim().toLowerCase().replace('.', '');
    if (cleaned === 'pfx') {
      return 'p12';
    }
    return cleaned.length > 0 ? cleaned : 'p12';
  }

  private static parseCertType(raw: string): http.CertType {
    const upper = raw.trim().toUpperCase();
    switch (upper) {
      case 'PEM':
        return http.CertType.PEM;
      case 'DER':
        return http.CertType.DER;
      default:
        return http.CertType.P12;
    }
  }

  private static safeAccess(path: string): boolean {
    try {
      return fs.accessSync(path);
    } catch (_) {
      return false;
    }
  }
}
