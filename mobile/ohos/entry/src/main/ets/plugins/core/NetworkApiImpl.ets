import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri, picker } from '@kit.CoreFileKit';
import ohosHttpFfi from 'libohos_http_ffi.so';
import { ClientCertData, ClientCertPrompt, FlutterError, NetworkApi, Result } from './Network.g';
import { URLSessionManager } from './URLSessionManager';

const CERT_SUFFIX_FILTERS: Array<string> = ['.p12', '.pfx'];

interface OhosHttpFfiSessionModule {
  setRequestState(headersJson: string, serverUrlsJson: string, token: string): number;
  setClientCertificate(certPath: string, keyPath: string, certType: string, keyPassword: string): number;
  clearClientCertificate(): number;
}

const ohosHttpFfiSessionModule = ohosHttpFfi as OhosHttpFfiSessionModule;

export class NetworkApiImpl extends NetworkApi {
  private ctx?: common.Context;
  private uiCtx?: common.UIAbilityContext;

  constructor(context: common.Context) {
    super();
    this.ctx = context;
    this.uiCtx = this.isUiContext(context) ? (context as common.UIAbilityContext) : undefined;
    this.syncStoredCertificateToCurl();
  }

  override addCertificate(clientData: ClientCertData, result: Result<void>): void {
    try {
      if (!this.ctx) {
        throw new Error('Context unavailable');
      }
      const data = clientData.getData();
      if (!data || data.length === 0) {
        throw new Error('Certificate data is empty');
      }
      const password = clientData.getPassword() ?? '';
      const bytes = new Uint8Array(data);
      const cert = URLSessionManager.saveFromBytes(this.ctx, bytes, password, 'p12');
      this.applyCurlClientCertificate(cert.certPath, cert.keyPath, cert.certType as string, cert.keyPassword ?? '');
      result.success();
    } catch (e) {
      result.error(e as Error);
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
      this.clearCurlClientCertificate();
      result.success();
    } catch (e) {
      result.error(e as Error);
    }
  }

  override hasCertificate(): boolean {
    if (!this.ctx) {
      return false;
    }
    return URLSessionManager.hasCertificate(this.ctx);
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

}
