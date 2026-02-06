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

export class NetworkClientCert {
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
    const cert = NetworkClientCert.load(context);
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
    if (NetworkClientCert.loaded) {
      return NetworkClientCert.cached;
    }
    const prefOptions: preferences.Options = { name: NetworkClientCert.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const certPath = pref.getSync(NetworkClientCert.KEY_CERT_PATH, '') as string;
    const keyPath = pref.getSync(NetworkClientCert.KEY_KEY_PATH, '') as string;
    if (!certPath || !keyPath) {
      NetworkClientCert.cached = null;
      NetworkClientCert.loaded = true;
      return null;
    }
    if (!NetworkClientCert.safeAccess(certPath)) {
      NetworkClientCert.clear(context);
      NetworkClientCert.cached = null;
      NetworkClientCert.loaded = true;
      return null;
    }
    const certTypeRaw = pref.getSync(NetworkClientCert.KEY_CERT_TYPE, 'P12') as string;
    const keyPassword = pref.getSync(NetworkClientCert.KEY_KEY_PASSWORD, '') as string;
    NetworkClientCert.cached = {
      certPath: certPath,
      keyPath: keyPath,
      certType: NetworkClientCert.parseCertType(certTypeRaw),
      keyPassword: keyPassword.length > 0 ? keyPassword : undefined,
    };
    NetworkClientCert.loaded = true;
    return NetworkClientCert.cached;
  }

  static saveFromBytes(
    context: common.Context,
    data: Uint8Array,
    password?: string,
    extension?: string
  ): StoredClientCert {
    const ext = NetworkClientCert.normalizeExtension(extension);
    const certType = http.CertType.P12;
    const certPath = NetworkClientCert.writeCertFile(context, data, ext);
    const keyPath = certPath;
    const record: StoredClientCert = {
      certPath,
      keyPath,
      certType,
      keyPassword: password && password.length > 0 ? password : undefined,
    };
    return NetworkClientCert.save(context, record);
  }

  static save(context: common.Context, cert: StoredClientCert): StoredClientCert {
    const prefOptions: preferences.Options = { name: NetworkClientCert.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    pref.putSync(NetworkClientCert.KEY_CERT_PATH, cert.certPath);
    pref.putSync(NetworkClientCert.KEY_KEY_PATH, cert.keyPath);
    pref.putSync(NetworkClientCert.KEY_CERT_TYPE, cert.certType as string);
    pref.putSync(NetworkClientCert.KEY_KEY_PASSWORD, cert.keyPassword ?? '');
    pref.flushSync();
    NetworkClientCert.cached = cert;
    NetworkClientCert.loaded = true;
    return cert;
  }

  static clear(context: common.Context): void {
    const prefOptions: preferences.Options = { name: NetworkClientCert.PREF_NAME };
    const pref = preferences.getPreferencesSync(context, prefOptions);
    const certPath = pref.getSync(NetworkClientCert.KEY_CERT_PATH, '') as string;
    const keyPath = pref.getSync(NetworkClientCert.KEY_KEY_PATH, '') as string;
    if (certPath && NetworkClientCert.safeAccess(certPath)) {
      try {
        fs.unlinkSync(certPath);
      } catch (_) {
        // ignore delete errors
      }
    }
    if (keyPath && keyPath !== certPath && NetworkClientCert.safeAccess(keyPath)) {
      try {
        fs.unlinkSync(keyPath);
      } catch (_) {
        // ignore delete errors
      }
    }
    pref.deleteSync(NetworkClientCert.KEY_CERT_PATH);
    pref.deleteSync(NetworkClientCert.KEY_KEY_PATH);
    pref.deleteSync(NetworkClientCert.KEY_CERT_TYPE);
    pref.deleteSync(NetworkClientCert.KEY_KEY_PASSWORD);
    pref.flushSync();
    NetworkClientCert.cached = null;
    NetworkClientCert.loaded = true;
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
    if (!NetworkClientCert.safeAccess(baseDir)) {
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
