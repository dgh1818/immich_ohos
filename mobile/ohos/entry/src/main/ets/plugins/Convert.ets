import { MapComponent, mapCommon, map} from '@kit.MapKit';
import { MapLibreMapController } from './MapLibreMapController';
import { MapLibreMapOptionsSink } from './MapLibreMapOptionsSink'
import { ArrayList } from '@kit.ArkTS';
import { Size } from '@ohos/hypium';

export class Convert {
  static interpretMapLibreMapOptions (options: ESObject, delegate:MapLibreMapOptionsSink):void {

    console.error("interpretMapLibreMapOptions enter");
    if(options == undefined) {
      console.error("options undefined");
    }

    let options_converted:Map<string,ESObject> = options as Map<string,ESObject>;
    if(options_converted == undefined) {
      console.error("options_converted undefined");
      return;
    }
    console.error("interpretMapLibreMapOptions enter30");
    options_converted.forEach((value:ESObject,key:string) => {
      console.error("list" + key);
    })
    options_converted.forEach((value:ESObject,key:string) => {
      console.error("current convert key is" + key);
      switch (key) {
        case 'cameraTargetBounds':
          console.error("size is " + value.size);

          // let cameraTargetBounds:Map<string,ESObject> = value as Map<string,ESObject>;
          //
          //
          // if(cameraTargetBounds==undefined) {
          //   console.error("cameraTargetBounds is undefined" );
          // } else {
          //   console.error("cameraTargetBounds size is " + cameraTargetBounds.size);
          // }
          //
          // cameraTargetBounds.forEach((value2:ESObject,key2:string) => {
          //   console.error("cameraTargetBounds is " + key2);
          // })


          // let cameraTargetBounds2:Map<string,ESObject> = cameraTargetBounds[0] as Map<string,ESObject>;
          // if(cameraTargetBounds2!=undefined) {
          //   console.error("cameraTargetBounds2 size is " + cameraTargetBounds2.size);
          // } else {
          //   console.error("cameraTargetBounds2 is undefined");
          // }
          //let cameraTargetBounds3:ArrayList<number> = cameraTargetBounds as ArrayList<number>;
          // if(cameraTargetBounds[0][0]!=undefined) {
          //   console.error("cameraTargetBounds[0][0] size is " + cameraTargetBounds[0][0]);
          // } else {
          //   console.error("cameraTargetBounds[0][0] is undefined");
          // }
          console.error("interpretMapLibreMapOptions enter12");
          //delegate.setCameraTargetBounds(Convert.toLatLngBounds(cameraTargetBounds[0]));
          console.error("interpretMapLibreMapOptions enter9");
          break;
        case 'compassEnabled':
          let compassEnabled = value as boolean;
          if(compassEnabled !=undefined) {
            delegate.setCompassEnabled(value);
          }
          break;
        case 'minMaxZoomPreference':
          let minMaxZoomPreference = options_converted.get("minMaxZoomPreference") as number[];
          delegate.setMinMaxZoomPreference(minMaxZoomPreference[0],minMaxZoomPreference[1]);
          break;
        case 'rotateGesturesEnabled':
          let rotateGesturesEnabled = options_converted.get("rotateGesturesEnabled") as boolean;
          delegate.setRotateGesturesEnabled(rotateGesturesEnabled);
          break;
        case 'scrollGesturesEnabled':
          let scrollGesturesEnabled = options_converted.get("scrollGesturesEnabled") as boolean;
          delegate.setScrollGesturesEnabled(scrollGesturesEnabled);
          break;
        case 'tiltGesturesEnabled':
          let tiltGesturesEnabled = options_converted.get("tiltGesturesEnabled") as boolean;
          delegate.setTiltGesturesEnabled(tiltGesturesEnabled);
          break;
        case 'trackCameraPosition':
          let trackCameraPosition = options_converted.get("trackCameraPosition") as boolean;
          //self.trackCameraPosition = trackCameraPosition
          delegate.setTrackCameraPosition(trackCameraPosition);
          break;
        case 'zoomGesturesEnabled':
          let zoomGesturesEnabled = options_converted.get("zoomGesturesEnabled") as boolean;
          delegate.setZoomGesturesEnabled(zoomGesturesEnabled);
          break;
        case 'myLocationEnabled':
          let myLocationEnabled = options_converted.get("myLocationEnabled") as boolean;
          delegate.setMyLocationEnabled(myLocationEnabled);
          break;
        case 'myLocationTrackingMode':
          let myLocationTrackingMode = options_converted.get("myLocationTrackingMode") as number;
          console.error("myLocationTrackingMode is" + myLocationTrackingMode);
          delegate.setMyLocationTrackingMode(myLocationTrackingMode);
          break;
        case 'logoViewMargins':
          let logoViewMargins = options_converted.get("logoViewMargins") as number[];
          delegate.setLogoViewMargins(logoViewMargins[0], logoViewMargins[1]);
          break;
        case 'compassViewPosition':
          let compassViewPosition = options_converted.get("compassViewPosition") as number;
          delegate.setCompassViewPosition(compassViewPosition);
          break;
        case 'compassViewMargins':
          let compassViewMargins = options_converted.get("compassViewMargins") as number[];
          delegate.setCompassViewMargins(compassViewMargins[0],compassViewMargins[1]);
          break;
        case 'attributionButtonMargins':
          let attributionButtonMargins = options_converted.get("attributionButtonMargins") as number[];
          delegate.setAttributionButtonMargins(attributionButtonMargins[0],attributionButtonMargins[1]);
          break;
      }
    })
    //setCompassViewPosition(position: mapCommon.MapPoint):void

    // if {options["attributionButtonPosition"] ！= null} {
    //
    // }

    //setAttributionButtonMargins

    //setLogoViewMargins(x:number, y:number):void

    //setMyLocationRenderMode(myLocationRenderMode:number):void

    //setMyLocationTrackingMode(myLocationTrackingMode:number):void

    //setZoomGesturesEnabled(zoomGesturesEnabled:boolean):void

  }

  static toLatLngBounds(o: number[][]): mapCommon.LatLngBounds {
    // if (o == null) {
    //   return null;
    // }
    let southwest_data: mapCommon.LatLng = {
      latitude: o[0][0],
      longitude: o[0][1]
    };

    let northeast_data: mapCommon.LatLng = {
      latitude: o[1][0],
      longitude: o[1][1]
    };

    let CoordinateBounds:mapCommon.LatLngBounds = {
      northeast: northeast_data,
      southwest: southwest_data
    }

    return CoordinateBounds
  }
}
