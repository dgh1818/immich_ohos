import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import { uri } from '@kit.ArkTS';
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
  token?: string;
}

export class URLSessionManager {
  private static readonly PREF_NAME = 'Immich::ClientCert';
  private static readonly KEY_CERT_PATH = 'certPath';
  private static readonly KEY_KEY_PATH = 'keyPath';
  private static readonly KEY_CERT_TYPE = 'certType';
  private static readonly KEY_KEY_PASSWORD = 'keyPassword';
  private static readonly KEY_HEADERS = 'requestHeaders';
  private static readonly KEY_SERVER_URLS = 'serverUrls';
  private static readonly KEY_TOKEN = 'authToken';
  private static readonly ACCESS_TOKEN_COOKIE = 'immich_access_token';
  private static readonly IS_AUTHENTICATED_COOKIE = 'immich_is_authenticated';
  private static readonly AUTH_TYPE_COOKIE = 'immich_auth_type';

  private static cached: StoredClientCert | null = null;
  private static loaded = false;
  private static cachedRequestState: StoredRequestState = { headers: {}, serverUrls: [] };
  private static requestStateLoaded = false;

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

    const effectiveHeaders = requestUrl
      ? URLSessionManager.applyAuthHeaders(mergedHeaders, requestState, requestUrl)
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

  static hasCertificate(context: common.Context): boolean {
    return URLSessionManager.load(context) !== null;
  }

  static setRequestHeaders(
    context: common.Context,
    headers: Map<string, string>,
    serverUrls: string[],
    token?: string
  ): void {
    const prefOptions: preferences.Options = { name: URLSessionManager.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const headerRecord = URLSessionManager.toHeaderRecord(headers);
    pref.putSync(URLSessionManager.KEY_HEADERS, JSON.stringify(headerRecord));
    pref.putSync(URLSessionManager.KEY_SERVER_URLS, JSON.stringify(serverUrls));

    if (token !== undefined && token !== null) {
      if (token.length > 0) {
        pref.putSync(URLSessionManager.KEY_TOKEN, token);
      } else {
        pref.deleteSync(URLSessionManager.KEY_TOKEN);
      }
    }

    pref.flushSync();
    URLSessionManager.cachedRequestState = {
      headers: headerRecord,
      serverUrls: Array.from(serverUrls),
      token: token !== undefined && token !== null
        ? (token.length > 0 ? token : undefined)
        : URLSessionManager.cachedRequestState.token,
    };
    URLSessionManager.requestStateLoaded = true;
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
    const token = pref.getSync(URLSessionManager.KEY_TOKEN, '') as string;

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
      token: token.length > 0 ? token : undefined,
    };
    URLSessionManager.requestStateLoaded = true;
    return URLSessionManager.cachedRequestState;
  }

  private static applyAuthHeaders(
    headers: Record<string, string>,
    requestState: StoredRequestState,
    requestUrl: string
  ): Record<string, string> {
    let effectiveHeaders = headers;
    const cookie = URLSessionManager.shouldAttachAuthCookie(requestState.serverUrls, requestUrl)
      ? URLSessionManager.buildAuthCookie(requestState.token)
      : undefined;
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

  private static shouldAttachAuthCookie(serverUrls: string[], requestUrl: string): boolean {
    const requestHost = URLSessionManager.getHost(requestUrl);
    if (!requestHost) {
      return false;
    }

    return serverUrls.some((url) => URLSessionManager.getHost(url) === requestHost);
  }

  private static buildAuthCookie(token?: string): string | undefined {
    if (!token || token.length === 0) {
      return undefined;
    }

    return `${URLSessionManager.ACCESS_TOKEN_COOKIE}=${token}; ` +
      `${URLSessionManager.IS_AUTHENTICATED_COOKIE}=true; ` +
      `${URLSessionManager.AUTH_TYPE_COOKIE}=password`;
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

  private static getHost(rawUrl: string): string {
    try {
      return new uri.URI(rawUrl).host;
    } catch (_) {
      return '';
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
