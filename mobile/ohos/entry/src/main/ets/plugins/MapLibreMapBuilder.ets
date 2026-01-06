import { MapComponent, mapCommon, map} from '@kit.MapKit';
import { AsyncCallback } from '@kit.BasicServicesKit'
import { Params } from '@ohos/flutter_ohos/src/main/ets/plugin/platform/PlatformView';
import { BinaryMessenger,
  MessageCodec,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  PlatformView, PlatformViewFactory,
  StandardMethodCodec } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { Convert } from './Convert'
import { MapLibreMapOptionsSink } from './MapLibreMapOptionsSink'
import { MapLibreMapController } from './MapLibreMapController'
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';

@Component
export struct MapOhosMap {
  @Prop public params: Params;

  private TAG = "MapOhosMap";
  private mapOptions?: mapCommon.MapOptions;
  private callback?: AsyncCallback<map.MapComponentController>;
  public mapController?: map.MapComponentController;
  private mapEventManager?: map.MapEventManager;
  public mapController_link: SubscribedAbstractProperty<map.MapComponentController> = AppStorage.link('mapController');
  public mapLibreMapController_link: SubscribedAbstractProperty<MapLibreMapController> = AppStorage.link('mapLibreMapController');
  public mapLibreMapController:MapLibreMapController = this.params.platformView as MapLibreMapController
  methodChannel:MethodChannel = this.mapLibreMapController.methodChannel;
  aboutToAppear(): void {
    //地图初始化参数，设置地图中心点坐标及层级
    this.mapOptions = {
      position: {
        target: {
          latitude: 39.9,
          longitude: 116.4
        },
        zoom: 10
      }
    };
    //地图初始化的回调
    this.callback = async (err, mapController) => {
      if (!err) {
        // 获取地图的控制器类，用来操作地图
        this.mapController = mapController;
        //this.mapLibreMapController_link.get().mapController = mapController;
        this.mapController_link.set(mapController);
        this.mapLibreMapController_link.get().init();
        this.mapEventManager = this.mapController.getEventManager();
        //this.mapController?.moveCamera(this.mapLibreMapController.cameraUpdate);
        let callback = () => {
          console.info(this.TAG, `on-mapLoad`);
          this.methodChannel.invokeMethod("map#onStyleLoaded", "");
        }
        this.mapEventManager.on("mapLoad", callback);
      }
    };
  }

  build() {
    Stack() {
      // 调用MapComponent组件初始化地图 const map_view2:MapComponent
      MapComponent({ mapOptions: this.mapOptions, mapCallback: this.callback }).width('100%').height('100%');
    }
  }
}

@Builder
export function MapOhosMapBuilder(params: Params) { // 需要通过@Builder的方式来导出原生组件
  MapOhosMap({ params: params })   // 注意这里的params参数必不可少
}
