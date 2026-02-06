import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { http } from '@kit.NetworkKit';
import fs from '@ohos.file.fs';

export interface StoredClientCert {
  certPath: string;
  keyPath: string;
  certType: http.CertType;
  keyPassword?: string;
}

export class URLSessionManager {
  private static readonly PREF_NAME = 'Immich::ClientCert';
  private static readonly KEY_CERT_PATH = 'certPath';
  private static readonly KEY_KEY_PATH = 'keyPath';
  private static readonly KEY_CERT_TYPE = 'certType';
  private static readonly KEY_KEY_PASSWORD = 'keyPassword';

  private static cached: StoredClientCert | null = null;
  private static loaded = false;

  static applyToOptions(context: common.Context | undefined, options: http.HttpRequestOptions): void {
    if (!context) {
      return;
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

