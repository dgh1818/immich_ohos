import { BinaryMessenger,
  MessageCodec,
  PlatformView, PlatformViewFactory,
 } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { MapLibreMapController } from './MapLibreMapController';

export class MapLibreMapFactory extends PlatformViewFactory {
  message: BinaryMessenger;

  constructor(message: BinaryMessenger, createArgsCodes: MessageCodec<Object>) {
    super(createArgsCodes);
    this.message = message;
  }

  public create(context: common.Context, viewId: number, args: Object): PlatformView {
    return new MapLibreMapController(context, viewId, args, this.message);  // 导出自定义的原生视图
  }
}
