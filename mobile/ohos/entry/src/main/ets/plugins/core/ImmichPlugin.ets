import { FlutterPlugin, FlutterPluginBinding } from '@ohos/flutter_ohos';

/**
 * Minimal plugin base to mirror Android's ImmichPlugin.
 * Tracks detach state so callbacks can be skipped after engine is torn down.
 */
export default class ImmichPlugin implements FlutterPlugin {
  private detached: boolean = false;

  getUniqueClassName(): string {
    return 'ImmichPlugin';
  }

  onAttachedToEngine(_binding: FlutterPluginBinding): void {
    this.detached = false;
  }

  detachFromEngine(): void {
    this.detached = true;
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.detachFromEngine();
  }

  protected completeWhenActive<T>(callback: (value: T) => void, value: T) {
    if (this.detached) {
      return;
    }
    callback(value);
  }
}
