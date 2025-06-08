import { MapComponent, mapCommon, map} from '@kit.MapKit';

export interface MapLibreMapOptionsSink {
  // todo: dddd replace with CameraPosition.Builder target
  setCameraTargetBounds(bounds:mapCommon.LatLngBounds):void

  setCompassEnabled(compassEnabled:boolean):void

  // // TODO: styleString is not actually a part of options. consider moving
  // fun setStyleString(styleString: String)
  setStyleString(styleString:string):void
  //
  // fun setMinMaxZoomPreference(min: Float?, max: Float?)
  setMinMaxZoomPreference(min?:number, max?:number):void
  //
  // fun setRotateGesturesEnabled(rotateGesturesEnabled: Boolean)
  setRotateGesturesEnabled(rotateGesturesEnabled:boolean):void
  //
  // fun setScrollGesturesEnabled(scrollGesturesEnabled: Boolean)
  setScrollGesturesEnabled(scrollGesturesEnabled:boolean):void
  //
  // fun setTiltGesturesEnabled(tiltGesturesEnabled: Boolean)
  setTiltGesturesEnabled(tiltGesturesEnabled:boolean):void
  //
  // fun setTrackCameraPosition(trackCameraPosition: Boolean)
  setTrackCameraPosition(trackCameraPosition:boolean):void
  //
  // fun setZoomGesturesEnabled(zoomGesturesEnabled: Boolean)
  setZoomGesturesEnabled(zoomGesturesEnabled:boolean):void
  //
  // fun setMyLocationEnabled(myLocationEnabled: Boolean)
  setMyLocationEnabled(myLocationEnabled:boolean):void
  //
  // fun setMyLocationTrackingMode(myLocationTrackingMode: Int)
  setMyLocationTrackingMode(myLocationTrackingMode:mapCommon.MyLocationDisplayType):void
  //
  // fun setMyLocationRenderMode(myLocationRenderMode: Int)
  setMyLocationRenderMode(myLocationRenderMode:mapCommon.MyLocationDisplayType):void
  //
  // fun setLogoViewMargins(x: Int, y: Int)
  setLogoViewMargins(x:number, y:number):void
  //
  setCompassViewPosition(position: number):void
  //

  setCompassViewMargins(x:number, y:number):void
  // fun setAttributionButtonGravity(gravity: Int)
  setAttributionButtonMargins(x:number,y:number):void

  setAttributionButtonPosition(position:number):void
  //
  // fun setAttributionButtonMargins(x: Int, y: Int)
  //
  // fun setLocationEngineProperties(locationEngineRequest: LocationEngineRequest)
}
