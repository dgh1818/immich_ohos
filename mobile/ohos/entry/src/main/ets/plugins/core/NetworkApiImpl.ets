import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileUri, picker } from '@kit.CoreFileKit';

import { ClientCertData, ClientCertPrompt, FlutterError, NetworkApi, Result } from './Network.g';
import { NetworkClientCert } from './NetworkClientCert';

const CERT_SUFFIX_FILTERS: Array<string> = ['.p12', '.pfx'];

export class NetworkApiImpl extends NetworkApi {
  private ctx?: common.Context;
  private uiCtx?: common.UIAbilityContext;

  constructor(context: common.Context) {
    super();
    this.ctx = context;
    this.uiCtx = this.isUiContext(context) ? (context as common.UIAbilityContext) : undefined;
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
      NetworkClientCert.saveFromBytes(this.ctx, bytes, password, 'p12');
      result.success();
    } catch (e) {
      result.error(e as Error);
    }
  }

  override async selectCertificate(promptText: ClientCertPrompt, result: Result<ClientCertData>): Promise<void> {
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
      const bytes = NetworkClientCert.readBytes(path);
      if (!bytes || bytes.byteLength === 0) {
        result.error(new Error('Certificate file is empty.'));
        return;
      }
      const cert = new ClientCertData(Array.from(bytes), '');
      result.success(cert);
    } catch (e) {
      if (this.isCancelError(e)) {
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
      NetworkClientCert.clear(this.ctx);
      result.success();
    } catch (e) {
      result.error(e as Error);
    }
  }

  private isUiContext(ctx: common.Context): boolean {
    return (ctx as common.UIAbilityContext).abilityInfo !== undefined;
  }

  private isCancelError(error: unknown): boolean {
    const err = error as BusinessError | Error | undefined;
    const message = err && (err as Error).message ? (err as Error).message.toLowerCase() : '';
    const name = err && (err as Error).name ? (err as Error).name.toLowerCase() : '';
    return message.includes('cancel') || name.includes('cancel');
  }
}
