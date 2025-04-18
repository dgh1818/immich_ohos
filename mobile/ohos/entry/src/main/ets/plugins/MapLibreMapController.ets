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
  PlatformViewWrapper,
  StandardMethodCodec } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { MapOhosMapBuilder,MapOhosMap } from './MapLibreMapBuilder'
import { Convert } from './Convert'
import { MapLibreMapOptionsSink } from './MapLibreMapOptionsSink'
import { image } from '@kit.ImageKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { resourceManager } from '@kit.LocalizationKit';

@Observed      //相当于widgetView
export class MapLibreMapController extends PlatformView implements MethodCallHandler {
  TAG: string = "MapLibreMapController";
  public mapController?: map.MapComponentController;
  public mapEventManager?: map.MapEventManager; // 存储事件管理器
  public cameraUpdate?: map.CameraUpdate;
  longitude: number = 39.9;
  latitude: number = 116.4;
  public methodChannel: MethodChannel;
  context?: common.Context;
  viewId?: number;
  args?: Object;
  //private var mapView: MLNMapView
  isMapReady: boolean = false;
  dragEnabled: boolean = true;
  isFirstStyleLoad: boolean = true;
  onStyleLoadedCalled: boolean = false;
  mapReadyResult?: MethodResult;
  // private var previousDragCoordinate: CLLocationCoordinate2D?
  // private var originDragCoordinate: CLLocationCoordinate2D?
  // private var dragFeature: MLNFeature?
  //
  // private var initialTilt: CGFloat?
  cameraTargetBounds?: mapCommon.LatLngBounds
  trackCameraPosition: boolean = false;
  myLocationEnabled: boolean = false;
  scrollingEnabled: boolean = true;
  args_input: Map<string, ESObject>;
  args_options: ESObject;
  pixelMap? : image.PixelMap;
  public mapController_link?: SubscribedAbstractProperty<map.MapComponentController>;
  public mapLibreMapController_link?: SubscribedAbstractProperty<MapLibreMapController>;

  constructor(context: common.Context, viewId: number, args: ESObject, message: BinaryMessenger) {
    super();
    AppStorage.setOrCreate('mapController', undefined);
    AppStorage.setOrCreate('mapLibreMapController', this);
    this.mapLibreMapController_link?.set(this);
    this.mapController_link = AppStorage.link('mapController');

    // 注册消息通道
    this.methodChannel =
      new MethodChannel(message, `plugins.flutter.io/maplibre_gl_${viewId}`, StandardMethodCodec.INSTANCE);
    this.methodChannel.setMethodCallHandler(this);
    console.error("set methodchannel success");

    this.args_input = args as Map<string, ESObject>;
    this.args_options = this.args_input.get("options");

    // if dragEnabled {
    //   let pan = UIPanGestureRecognizer(
    //     target: self,
    //   action: #selector(handleMapPan(sender:))
    //   )
    //   pan.delegate = self
    //   mapView.addGestureRecognizer(pan)
    // }
    //
    // if(!longPressRecognizerAdded) {
    //   mapView.addGestureRecognizer(longPress)
    //   longPressRecognizerAdded = true
    //}
  }

  public setCameraTargetBounds(bounds: mapCommon.LatLngBounds): void {
    this.cameraTargetBounds = bounds;
    this.mapController!.setLatLngBounds(this.cameraTargetBounds);
  }

  // static interpretMapLibreMapOptions = (options: ESObject, delegate:MapLibreMapOptionsSink) =>
  public setCompassEnabled(compassEnabled: boolean): void {
    console.error("enter setCompassEnabled controller");
    this.mapController!.setCompassControlsEnabled(compassEnabled);
    console.error("leave setCompassEnabled controller");
  }

  public setMinMaxZoomPreference(min?: number, max?: number): void {
    this.mapController?.setMinZoom(min);
    this.mapController?.setMaxZoom(max);
  }

  public setStyleString(styleString: string): void {
    if (styleString.length == 0)
      console.log("setStyleString - string empty"); else if (styleString.startsWith("{") ||
    styleString.startsWith("[")) {
      console.log("setStyleString - JSON style currently not supported");
      // Currently the iOS MapLibre SDK does not have a builder for json.

    } else if (!isNaN(parseInt(styleString))) {

      let styleType: mapCommon.CustomMapStyleOptions = {
        styleId: "parseInt(styleString)"
      };
      this.mapController?.setCustomMapStyle(styleType);
    } else {
      // Absolute path
      console.log("setStyleString - Absolute path currently not supported");
    }
  }

  //
  // fun setRotateGesturesEnabled(rotateGesturesEnabled: Boolean)
  public setRotateGesturesEnabled(rotateGesturesEnabled: boolean): void {
    this.mapController?.setRotateGesturesEnabled(rotateGesturesEnabled);
  }

  //
  // fun setScrollGesturesEnabled(scrollGesturesEnabled: Boolean)
  public setScrollGesturesEnabled(scrollGesturesEnabled: boolean): void {
    this.mapController?.setScrollGesturesEnabled(scrollGesturesEnabled);
    this.scrollingEnabled = scrollGesturesEnabled
  }

  //
  // fun setTiltGesturesEnabled(tiltGesturesEnabled: Boolean)
  public setTiltGesturesEnabled(tiltGesturesEnabled: boolean): void {
    this.mapController?.setTiltGesturesEnabled(tiltGesturesEnabled);
  }

  public setTrackCameraPosition(trackCameraPosition: boolean): void {
    this.trackCameraPosition = trackCameraPosition;
  }

  public setZoomGesturesEnabled(zoomGesturesEnabled: boolean): void {
    this.mapController?.setZoomControlsEnabled(zoomGesturesEnabled);
  }

  public setMyLocationEnabled(myLocationEnabled: boolean): void {
    if (this.myLocationEnabled == myLocationEnabled) {
      return
    }
    this.myLocationEnabled = myLocationEnabled
    this.updateMyLocationEnabled()
  }

  private updateMyLocationEnabled(): void {
    this.mapController?.setMyLocationEnabled(this.myLocationEnabled);
  }

  public setMyLocationTrackingMode(myLocationTrackingMode: number): void {
    let mode: mapCommon.MyLocationDisplayType;
    if (myLocationTrackingMode == 0) {
      mode = mapCommon.MyLocationDisplayType.DEFAULT;
    } else if (myLocationTrackingMode == 1) {
      mode = mapCommon.MyLocationDisplayType.FOLLOW_ROTATE;
    } else if (myLocationTrackingMode == 2) {
      mode = mapCommon.MyLocationDisplayType.FOLLOW_ROTATE; //无对应
    } else if (myLocationTrackingMode == 3) {
      mode = mapCommon.MyLocationDisplayType.FOLLOW;
    } else {
      mode = mapCommon.MyLocationDisplayType.FOLLOW;
    }
    let style: mapCommon.MyLocationStyle = {
      displayType: mode!
    };

    this.mapController?.setMyLocationStyle(style);
  }

  //未找到对应
  public setMyLocationRenderMode(myLocationRenderMode: mapCommon.MyLocationDisplayType): void {
    console.info("setMyLocationRenderMode not implemented");
  }

  public setLogoViewMargins(x: number, y: number): void {
    let padding: mapCommon.Padding = {
      left: x,
      bottom: y
    };

    this.mapController?.setLogoPadding(padding);
  }

  public setCompassViewPosition(position: number): void {
    console.log("setCompassViewPosition - OHOS not supported");
  }

  public setCompassViewMargins(x: number, y: number): void {
    let point: mapCommon.MapPoint = {
      positionX: x,
      positionY: y
    };
    this.mapController?.setCompassPosition(point)
  }

  public setAttributionButtonMargins(x: number, y: number): void {
    console.log("setAttributionButtonMargins - OHOS not supported");
  }

  public setAttributionButtonPosition(position: number): void {
    console.log("setAttributionButtonPosition - OHOS not supported");
  }

  public init(): void {
    this.mapController = this.mapController_link!.get();

    if (this.args_input.get('options') == undefined) {
      console.error("this.args_input is undefined");
    } else {
      Convert.interpretMapLibreMapOptions(this.args_options, this)
      console.info("interpretMapLibreMapOptions ok");

      if (this.args_input.get("initialCameraPosition") != undefined) {
        let initialCameraPosition: Map<string, ESObject> =
          this.args_input.get("initialCameraPosition") as Map<string, ESObject>;
        let target = initialCameraPosition.get("target") as number[];
        let zoom = initialCameraPosition.get("zoom") as number;
        let tilt = initialCameraPosition.get("tilt") as number; //倾斜角
        let bearing = initialCameraPosition.get("bearing") as number;
        if (bearing == undefined) {
          console.error("bearing == undefined")
          bearing = 0;
        }
        let latitude = target[0]
        let longitude = target[1]
        if (target != null && zoom != null && tilt != null) {
          let cameraPosition: mapCommon.CameraPosition = {
            target: {
              latitude: latitude,
              longitude: longitude
            },
            zoom: zoom,
            tilt: tilt,
            bearing: bearing
          };

          this.cameraUpdate = map.newCameraPosition(cameraPosition);
          this.mapController?.moveCamera(this.cameraUpdate);
        }

        if (this.args_input.get("dragEnabled") != undefined) {
          let enabled = this.args_input.get("dragEnabled") as boolean;
          this.dragEnabled = enabled;
        }
      }
    }
    console.info("Map Init Finished");
  }


  onMethodCall(call: MethodCall, result: MethodResult): void {
    // 接受Dart侧发来的消息
    let method: string = call.method;
    let projection: map.Projection;
    let call_args: Map<string, ESObject> = call.args as Map<string, ESObject>;
    console.error("enter method:" + method);
    switch (method) {
      case "map#waitForMap":

        //this.startWaitCallback(result);
        if (this.mapController != undefined) {
          console.error("success map#waitForMap");
          result.success(true);
          // if (this.isFirstStyleLoad) {
          //   this.isFirstStyleLoad = false
          //
          //   this.onStyleLoadedCalled = true
          //   this.methodChannel.invokeMethod("map#onStyleLoaded", "");
          //   console.error("success map#waitForMap");
          //
          // }
          return;
        }
        //result.success(true);
        console.error("this.mapController underfined");
        result.success(true);
        this.mapReadyResult = result;
        break;
      case 'map#addMarkerAtLatLng':
        console.error("enter map#addMarkerAtLatLng")

        let mark_longitude: number = call_args.get('longitude') as number;
        let mark_latitude: number = call_args.get('latitude') as number;
        let factor: number = call_args.get('iconSize') as number;
        let file = call_args.get('path') as string;
        let bytes = call_args.get('bytes') as Uint8Array;
        let image_data: image.ImageSource = image.createImageSource(bytes.buffer);
        let imageInfo = image_data.getImageInfoSync(0);
        imageInfo.size.height*factor
        let mark_size:image.Size = {
          height: imageInfo.size.height*factor,
          width: imageInfo.size.width*factor
        }
        let decodingOptions : image.DecodingOptions = {
          editable: true,
          desiredPixelFormat: 3,
          desiredSize: mark_size
        }
        // 创建pixelMap
        this.pixelMap  = image_data.createPixelMapSync(decodingOptions);

        if (mark_longitude == undefined || mark_latitude == undefined || file == undefined) {
          console.error("marker undefined")
        }

        console.error("latitude=" + mark_latitude + "longitude" + mark_longitude);

        let markerOptions: mapCommon.MarkerOptions = {
          position: {
            latitude: mark_latitude,
            longitude: mark_longitude
          },
          rotation: 0,
          visible: true,
          zIndex: 0,
          alpha: 1,
          anchorU: 0.5,
          anchorV: 1,
          clickable: false,
          draggable: false,
          flat: false,
          // 图标存放在resources/rawfile
          icon: this.pixelMap
        };

        console.error("enter controller marker");
        this.mapController?.addMarker(markerOptions);
        console.error("leave controller marker");
        result.success(true);
        break;

      case "map#getVisibleRegion":
        //var reply = [String: NSObject]()
        projection = this.mapController!.getProjection();
        let visibleRegion: mapCommon.VisibleRegion = projection.getVisibleRegion();
        let reply_sw: ESObject = [visibleRegion.nearLeft.latitude, visibleRegion.nearLeft.longitude] as ESObject
        let reply_ne: ESObject = [visibleRegion.farRight.latitude, visibleRegion.farRight.longitude] as ESObject
        result.success({
          "sw": reply_sw,
          "ne": reply_ne
        });
        break;
      case "map#toScreenLocation":
        let longitude: number = call_args.get('longitude') as number;
        let latitude: number = call_args.get('latitude') as number;
        console.error("longitude=" + longitude);
        console.error("latitude=" + latitude);
        let currentPoint: mapCommon.MapPoint = {
          positionX: longitude,
          positionY: latitude
        };
        console.error("enter projection");
        if (this.mapController==undefined) {
          console.error("this.mapController = undefined");
        }
        projection = this.mapController?.getProjection()!;


        console.error("leave projection");
        let latLng: mapCommon.LatLng = projection.fromScreenLocation(currentPoint);
        console.error("leave fromScreenLocation");

        result.success({
          "x": latLng.latitude,
          "y": latLng.longitude
        });
        break;
      // case "style#addImageSource":
      //   //let argument:ESObject = call.args as ESObject;
      //   let imageSourceId = call.args["imageSourceId"] as String
      //   let bytes = call.args["bytes"] as Uint8Array
      //   //bytes.buffer
      //   let image_data: image.ImageSource = image.createImageSource(bytes.buffer);
      //   let width:number
      //   let height:number
      //   let new_width:number
      //   let desired_size:image.Size
      //   let decodingOptions: image.DecodingOptions
      //   let pixelmap:PixelMap
      //   //imageSourceApi.getImageInfo(0, (error: BusinessError, imageInfo: image.ImageInfo) => {
      //   image_data.getImageInfo(0)
      //     .then((imageInfo: image.ImageInfo) => {
      //       width = imageInfo.size.width;
      //       height = imageInfo.size.height;
      //       new_width = width / height * call.argument("length") ;
      //       desired_size.height = call.argument("length");
      //       desired_size.width = call.argument("new_width");
      //       decodingOptions = {
      //         desiredSize:desired_size,
      //       }
      //
      //       image_data.createPixelMap().then((pixelMap: image.PixelMap) => {
      //         pixelmap = pixelMap;
      //         console.info('Succeeded in creating pixelMap object through image decoding parameters.');
      //       })
      //     }).catch((error: BusinessError) => {
      //     console.error(`Failed to obtain the image information.code is ${error.code}, message is ${error.message}`);
      //   })
      //
      //   let context = this.context;
      //   let resourceManager = context!.resourceManager;

      //let map:Resource

      //     image_data.createPixelMap()
      //
      //     //image_info.size
      //     this.style?.add
      //     this.style?.addImage(
      //       call.args("name"),
      //       pixelmap!,
      //     );

      // result.success(null);
      // break;
    }

    // let imageOverlayParams: mapCommon.ImageOverlayParams = {
    //   image: image_data,
    //   height: call.args("length")
    // };
    // let imageOverlay = this.mapController?.addImageOverlay(imageOverlayParams);
    // result.success({});
    // call.argument("name"),
    // BitmapFactory.decodeByteArray(call.argument("bytes"), 0, call.argument("length")),
    // call.argument("sdf"));
    // this.a3a?.addImage(
    //   call.args["name"],
    //   image.createPixelMap(image_data)
    // )


    //guard let image = UIImage(data: data) else { return }

    //guard let coordinates = arguments["coordinates"] as? [[Double]] else { return }

  }

  getView(): WrappedBuilder<[Params]> {
    return new WrappedBuilder(MapOhosMapBuilder);
  }

  dispose(): void {
  }
}
