import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import { cert } from '@kit.DeviceCertificateKit';
import fs from '@ohos.file.fs';
import ohosHttpFfi from 'libohos_http_ffi.so';
import util from '@ohos.util';
import { ClientCertData, ClientCertPrompt, FlutterError, NetworkApi, Result } from './Network.g';
import { URLSessionManager } from './URLSessionManager';

const CERT_SUFFIX_FILTERS: Array<string> = ['.p12', '.pfx'];
const CERTIFICATE_NO_CA_BUNDLE_STATUS = 6;

interface OhosHttpFfiSessionModule {
  setRequestState(headersJson: string, serverUrlsJson: string, token: string): number;
  setClientCertificate(certPath: string, keyPath: string, certType: string, keyPassword: string): number;
  clearClientCertificate(): number;
  setCaBundlePath(caBundlePath: string): number;
  extractCaBundleFromPkcs12(pkcs12Path: string, password: string, outputPath: string): number;
}

const ohosHttpFfiSessionModule = ohosHttpFfi as OhosHttpFfiSessionModule;

export class NetworkApiImpl extends NetworkApi {
  private ctx?: common.Context;
  private uiCtx?: common.UIAbilityContext;
  // Worker threads receive an ApplicationContext whose filesDir differs from
  // the UIAbilityContext (e.g. /data/storage/el2/base/files vs …/haps/entry/files).
  // CA bundle files MUST be written under the ApplicationContext so both the
  // main thread and worker threads can access them.
  private appFilesDir: string;

  constructor(context: common.Context) {
    super();
    this.ctx = context;
    this.uiCtx = this.isUiContext(context) ? (context as common.UIAbilityContext) : undefined;
    this.appFilesDir = context.getApplicationContext().filesDir;
    console.info(`[NetworkApiImpl] constructor: ctx.filesDir=${context.filesDir} appFilesDir=${this.appFilesDir}`);
    this.syncStoredCertificateToCurl();
    this.syncCaBundlePathToCurl();
  }

  override async addCertificate(clientData: ClientCertData, result: Result<void>): Promise<void> {
    let didSaveCertificate = false;
    try {
      if (!this.ctx) {
        throw new Error('Context unavailable');
      }
      const data = clientData.getData();
      if (!data || data.length === 0) {
        throw new Error('Certificate data is empty');
      }
      const password = clientData.getPassword() ?? '';
      console.info(`[NetworkApiImpl] addCertificate: PKCS12 size=${data.length} hasPassword=${password.length > 0}`);
      const bytes = new Uint8Array(data);
      const parsingConfig: cert.Pkcs12ParsingConfig = {
        password: password,
        needsPrivateKey: true,
        privateKeyFormat: cert.EncodingBaseFormat.PEM,
        needsCert: true,
        needsOtherCerts: true,
      };
      const parsed = cert.parsePkcs12(bytes, parsingConfig);
      const hasParsedCert = parsed.cert !== undefined;
      const hasParsedKey = parsed.privateKey !== undefined;
      console.info(`[NetworkApiImpl] addCertificate: parsed cert=${hasParsedCert} key=${hasParsedKey}`);

      // Extract CA trust anchors regardless of whether a client certificate is
      // present — a PKCS12 may contain only CA certificates for server
      // verification (no mTLS).
      const trustAnchors = await cert.createTrustAnchorsWithKeyStore(bytes, password);
      console.info(`[NetworkApiImpl] addCertificate: trustAnchors count=${trustAnchors.length}`);

      const hasClientCert = parsed.cert !== undefined && parsed.privateKey !== undefined;

      if (!hasClientCert && trustAnchors.length === 0) {
        throw new Error('PKCS12 does not contain a client certificate or a usable trust anchor.');
      }

      if (hasClientCert) {
        console.info('[NetworkApiImpl] addCertificate: mTLS path (client cert present)');
        // mTLS path: persist the client certificate for per-request use.
        const storedCert = URLSessionManager.saveFromBytes(this.ctx, bytes, password, 'p12');
        didSaveCertificate = true;
        this.deleteCaBundleFile();
        if (trustAnchors.length > 0) {
          await this.writeCaBundleFromTrustAnchors(trustAnchors);
        }
        this.applyCurlClientCertificate(
          storedCert.certPath,
          storedCert.keyPath,
          storedCert.certType as string,
          storedCert.keyPassword ?? ''
        );
      } else {
        // Server CA trust path: write the CA bundle only, no client cert.
        console.info('[NetworkApiImpl] addCertificate: CA-only path (no client cert)');
        this.deleteCaBundleFile();
        await this.writeCaBundleFromTrustAnchors(trustAnchors);
        const caPath = this.caBundlePath();
        const exists = this.safeAccess(caPath);
        const fileSize = exists ? (() => { try { return fs.statSync(caPath).size; } catch (_) { return -1; } })() : -1;
        console.info(`[NetworkApiImpl] addCertificate: caBundle written path=${caPath} exists=${exists} size=${fileSize}`);
      }

      this.syncCaBundlePathToCurl();
      console.info('[NetworkApiImpl] addCertificate: success');
      result.success();
    } catch (e) {
      if (didSaveCertificate && this.ctx) {
        try {
          URLSessionManager.clear(this.ctx);
          this.clearCurlClientCertificate();
          this.syncCaBundlePathToCurl();
        } catch (_) {
          // Preserve the original import error for Dart logging.
        }
      }
      const error = e as BusinessError;
      const code = error.code !== undefined ? `${error.code}` : 'CERTIFICATE_IMPORT_FAILED';
      const name = error.name ?? 'certificate_import_failed';
      const message = error.message ?? `${e}`;
      result.error(new FlutterError(code, name, message, error.stack));
    }
  }

  override async selectCertificate(_promptText: ClientCertPrompt, result: Result<ClientCertData>): Promise<void> {
    if (!this.uiCtx) {
      result.error(new FlutterError('NO_UI', 'no_ui', 'UI context is required to pick a certificate.'));
      return;
    }
    try {
      const documentPicker = new picker.DocumentViewPicker(this.uiCtx);
      const options = new picker.DocumentSelectOptions();
      options.fileSuffixFilters = CERT_SUFFIX_FILTERS;
      options.maxSelectNumber = 1;
      const uris = await documentPicker.select(options);
      if (!uris || uris.length === 0) {
        result.error(new FlutterError('CANCELLED', 'cancelled', 'No certificate selected.'));
        return;
      }
      const uri = uris[0];
      const path = new fileUri.FileUri(uri).path;
      const bytes = URLSessionManager.readBytes(path);
      if (!bytes || bytes.byteLength === 0) {
        result.error(new Error('Certificate file is empty.'));
        return;
      }

      result.success(new ClientCertData(bytes, ''));
    } catch (e) {
      let error = e as BusinessError;
      if (this.isCancelError(error)) {
        result.error(new FlutterError('CANCELLED', 'cancelled', 'User cancelled certificate selection.'));
        return;
      }
      result.error(e as Error);
    }
  }

  override removeCertificate(result: Result<void>): void {
    try {
      if (!this.ctx) {
        throw new Error('Context unavailable');
      }
      URLSessionManager.clear(this.ctx);
      this.deleteCaBundleFile();
      this.clearCurlClientCertificate();
      this.syncCaBundlePathToCurl();
      result.success();
    } catch (e) {
      result.error(e as Error);
    }
  }

  override hasCertificate(): boolean {
    if (!this.ctx) {
      return false;
    }
    if (URLSessionManager.hasCertificate(this.ctx)) {
      return true;
    }
    // A CA bundle may have been imported without a client certificate.
    return this.safeAccess(this.caBundlePath());
  }

  override getClientPointer(): number {
    // OHOS requests use NetworkKit directly; there is no shared native client pointer.
    return 0;
  }

  override getAppGroupId(): string {
    return this.ctx?.applicationInfo.name ?? '';
  }

  override setRequestHeaders(headers: Map<string, string>, serverUrls: Array<string>, token: string | null): void {
    if (!this.ctx) {
      return;
    }
    URLSessionManager.setRequestHeaders(this.ctx, headers, serverUrls, token);
    this.syncRequestStateToCurl(headers, serverUrls, token);
  }

  private isUiContext(ctx: common.Context): boolean {
    return (ctx as common.UIAbilityContext).abilityInfo !== undefined;
  }

  private isCancelError(err: BusinessError): boolean {
    const message = err && (err as Error).message ? (err as Error).message.toLowerCase() : '';
    const name = err && (err as Error).name ? (err as Error).name.toLowerCase() : '';
    return message.includes('cancel') || name.includes('cancel');
  }

  private syncStoredCertificateToCurl(): void {
    if (!this.ctx) {
      return;
    }
    const cert = URLSessionManager.load(this.ctx);
    if (!cert) {
      this.clearCurlClientCertificate();
      return;
    }
    this.applyCurlClientCertificate(cert.certPath, cert.keyPath, cert.certType as string, cert.keyPassword ?? '');
  }

  private syncRequestStateToCurl(headers: Map<string, string>, serverUrls: Array<string>, token: string | null): void {
    const curlHeaders = URLSessionManager.buildTransportHeaders(headers);
    const status = ohosHttpFfiSessionModule.setRequestState(
      JSON.stringify(curlHeaders),
      JSON.stringify(serverUrls),
      token ?? ''
    );
    if (status !== 0) {
      throw new Error(`Failed to synchronize curl request state: ${status}`);
    }
  }

  private applyCurlClientCertificate(certPath: string, keyPath: string, certType: string, keyPassword: string): void {
    const status = ohosHttpFfiSessionModule.setClientCertificate(certPath, keyPath, certType, keyPassword);
    if (status !== 0) {
      throw new Error(`Failed to synchronize curl client certificate: ${status}`);
    }
  }

  private clearCurlClientCertificate(): void {
    const status = ohosHttpFfiSessionModule.clearClientCertificate();
    if (status !== 0) {
      throw new Error(`Failed to clear curl client certificate: ${status}`);
    }
  }

  private syncCaBundlePathToCurl(validatePkcs12: boolean = false): void {
    const caBundlePath = this.resolveCaBundlePath(validatePkcs12);
    console.info(`[NetworkApiImpl] syncCaBundlePathToCurl: resolved path='${caBundlePath}'`);
    // Empty string clears the previously configured custom bundle and lets
    // libcurl fall back to its default trust behavior.
    const status = ohosHttpFfiSessionModule.setCaBundlePath(caBundlePath);
    console.info(`[NetworkApiImpl] syncCaBundlePathToCurl: setCaBundlePath status=${status}`);
    if (status !== 0) {
      throw new Error(`Failed to set curl CA bundle path: ${status}`);
    }
  }

  /**
   * Resolves the CA bundle path to use for curl server certificate
   * verification.  The bundle must be placed in the same sandbox directory
   * that URLSessionManager uses for client certificates.
   */
  private resolveCaBundlePath(validatePkcs12: boolean): string {
    if (!this.ctx) {
      return '';
    }

    // Same directory as client cert imports (URLSessionManager.writeCertFile).
    const caBundlePath = this.caBundlePath();
    if (this.safeAccess(caBundlePath)) {
      return caBundlePath;
    }

    // When a client certificate PKCS12 has been imported, try to use its
    // embedded CA chain as a trust anchor for server verification.  Many
    // mTLS deployments bundle the issuing CA in the same PKCS12.
    const cert = URLSessionManager.load(this.ctx);
    if (cert && cert.certPath && this.safeAccess(cert.certPath)) {
      try {
        return this.extractCaBundleFromClientCert(cert.certPath, cert.keyPassword ?? '');
      } catch (e) {
        if (validatePkcs12) {
          throw e as Error;
        }
      }
    }

    return '';
  }

  /**
   * If the client certificate PKCS12 contains CA certificates, this
   * helper extracts them into a PEM bundle that curl can consume.
   */
  private extractCaBundleFromClientCert(pkcs12Path: string, password: string): string {
    if (!this.ctx) {
      throw new Error('Context unavailable');
    }

    const targetDir = `${this.appFilesDir}/ssl_client_cert`;
    if (!this.safeAccess(targetDir)) {
      try {
        fs.mkdirSync(targetDir, true);
      } catch (e) {
        throw new Error(`Failed to create certificate directory: ${(e as Error).message}`);
      }
    }
    const outputPath = this.caBundlePath();

    const status = ohosHttpFfiSessionModule.extractCaBundleFromPkcs12(pkcs12Path, password, outputPath);
    if (status === CERTIFICATE_NO_CA_BUNDLE_STATUS) {
      this.deletePath(outputPath);
      return '';
    }
    if (status !== 0) {
      this.deletePath(outputPath);
      throw new Error(`Failed to extract curl CA bundle from PKCS12: ${status}`);
    }

    if (!this.safeAccess(outputPath)) {
      throw new Error(`Extracted curl CA bundle is missing: ${outputPath}`);
    }
    return outputPath;
  }

  private async writeCaBundleFromTrustAnchors(trustAnchors: Array<cert.X509TrustAnchor>): Promise<void> {
    try {
      console.info(`[NetworkApiImpl] writeCaBundleFromTrustAnchors: ${trustAnchors.length} trust anchors`);
      let pemBundle = '';
      for (const trustAnchor of trustAnchors) {
        if (!trustAnchor.CACert) {
          continue;
        }
        const encoded = await trustAnchor.CACert.getEncoded();
        pemBundle += this.toPemCertificate(encoded.data);
      }
      console.info(`[NetworkApiImpl] writeCaBundleFromTrustAnchors: PEM bundle length=${pemBundle.length}`);
      if (pemBundle.length === 0) {
        throw new Error('PKCS12 trust anchors do not contain CA certificates.');
      }

      if (!this.ctx) {
        throw new Error('Context unavailable');
      }
      const targetDir = `${this.appFilesDir}/ssl_client_cert`;
      if (!this.safeAccess(targetDir)) {
        fs.mkdirSync(targetDir, true);
      }

      const outputPath = this.caBundlePath();
      const file = fs.openSync(outputPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
      try {
        fs.truncateSync(file.fd, 0);
        fs.writeSync(file.fd, pemBundle);
        fs.truncateSync(file.fd, pemBundle.length);
      } catch (e) {
        throw new Error(`Failed to write CA bundle file: ${(e as Error).message}`);
      } finally {
        try {
          fs.closeSync(file);
        } catch (_) {}
      }
    } catch (e) {
      throw new Error(`Failed to write PKCS12 trust anchors: ${(e as Error).message}`);
    }
  }

  private toPemCertificate(data: Uint8Array): string {
    const base64 = new util.Base64Helper().encodeToStringSync(data);
    let body = '';
    for (let offset = 0; offset < base64.length; offset += 64) {
      body += `${base64.substring(offset, offset + 64)}\n`;
    }
    return `-----BEGIN CERTIFICATE-----\n${body}-----END CERTIFICATE-----\n`;
  }

  private caBundlePath(): string {
    if (!this.ctx) {
      return '';
    }
    // Use ApplicationContext filesDir so Worker threads can access the same file.
    return `${this.appFilesDir}/ssl_client_cert/ca_bundle.pem`;
  }

  private deleteCaBundleFile(): void {
    const caBundlePath = this.caBundlePath();
    if (caBundlePath.length > 0) {
      this.deletePath(caBundlePath);
    }
  }

  private deletePath(filePath: string): void {
    if (this.safeAccess(filePath)) {
      try {
        fs.unlinkSync(filePath);
      } catch (e) {
        throw new Error(`Failed to delete certificate file ${filePath}: ${(e as Error).message}`);
      }
    }
  }

  private safeAccess(filePath: string): boolean {
    try {
      return fs.accessSync(filePath);
    } catch (_) {
      return false;
    }
  }

}
