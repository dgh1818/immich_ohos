import { MapComponent, mapCommon, map} from '@kit.MapKit';
import { MapLibreMapController } from './MapLibreMapController';
import { MapLibreMapOptionsSink } from './MapLibreMapOptionsSink'
import { ArrayList, url } from '@kit.ArkTS';
import { Size } from '@ohos/hypium';
import { MapOhosMapBuilder,MapOhosMap } from './MapLibreMapBuilder'

export class SourcePropertyConverter {
  // static buildShapeSource(identifier: string, properties: Map<string,ESObject>) {
  //   let options = interpretShapeOptions(properties: properties)
  //   // if let data = properties["data"] as? String, let url = URL(string: data) {
  //   //   return MLNShapeSource(identifier: identifier, url: url, options: options)
  //   // }
  //   if let data = properties["data"] {
  //     do {
  //       let geoJsonData = try JSONSerialization.data(withJSONObject: data)
  //       let shape = try MLNShape(data: geoJsonData, encoding: String.Encoding.utf8.rawValue)
  //       return MLNShapeSource(identifier: identifier, shape: shape, options: options)
  //     } catch {}
  //   }
  //   return nil
  // }
  static addSource(id: string, properties: Map<string, ESObject>, style: MapLibreMapController) {
    let type: string = properties.get("type") as string;
    // Source
    // source = null;
    let source:ESObject;

    if (type != null) {
      switch (type) {
        // case "vector":
        //   source = buildVectorSource(id, properties);
        //   break;
        // case "raster":
        //   source = buildRasterSource(id, properties);
        //   break;
        // case "raster-dem":
        //   source = buildRasterDemSource(id, properties);
        //   break;
        // case "image":
        //   source = buildImageSource(id, properties);
        //   break;
        case "geojson":
          source = SourcePropertyConverter.buildGeojsonSource(id, properties);
          break;
        default:
        // unsupported source type
      }
    }

    if (source != null) {
      if(type == 'geojson'){
        style.sourceCommon?.set('id',source as ESObject);
      }
    }
  }

  static buildGeojsonSource(id: string, properties: Map<string, ESObject>): GeoJsonSource|undefined {
    let data:ESObject = properties.get("data");
    //let option:GeoJsonOptions = buildGeojsonOptions(properties);
    if (data != undefined) {
      if (data as string !=undefined) {
        // try {
        //   uri:url = new URI(Convert.toString(data));
        //   return new GeoJsonSource(id, uri, options);
        // } catch (URISyntaxException e) {
        // }
      } else {
        let geojson:string = JSON.stringify(data);
        let featureCollection:Map<string,ESObject> = JSON.parse(geojson)
        return new GeoJsonSource(id, featureCollection, properties);
      }
    }
    return undefined;
      //let pointOptions: mapCommon.PointAnnotationParams;

      let maxzoom = properties.get("maxzoom") as number;
      // if(maxzoom!=undefined) {
      //   pointOptions!.maxZoom = maxzoom
      // }

      //   // if let buffer = properties["buffer"] as? Double {
      //   //   options[.buffer] = buffer
      //   // }
      // if let tolerance = properties["tolerance"] as? Double {
      //   options[.simplificationTolerance] = tolerance
      // }
      //
      // if let cluster = properties["cluster"] as? Bool {
      //   options[.clustered] = cluster
      // }
      // if let clusterRadius = properties["clusterRadius"] as? Double {
      //   options[.clusterRadius] = clusterRadius
      // }
      // if let clusterMaxZoom = properties["clusterMaxZoom"] as? Double {
      //   options[.maximumZoomLevelForClustering] = clusterMaxZoom
      // }
      //
      // // TODO: clusterProperties not implemneted for IOS
      //
      // if let lineMetrics = properties["lineMetrics"] as? Bool {
      //   options[.lineDistanceMetrics] = lineMetrics
      // }
      //return markerOptions
  }
}

class GeoJsonSource {
  id?:string;
  featureCollection?:Map<string,ESObject>;
  properties?:Map<String, Object>;
  public features?:Map<string,ESObject>;
  public type?:string;
  public featureAssestId?:string;
  public geometry?:ESObject;
  public geometryType?:string;
  public coordinatesInput?:number[];
  public coordinates?:mapCommon.LatLng;

  constructor(id:string,featureCollection?:Map<string,ESObject>,properties?:Map<string, ESObject>) {
    this.id=id;
    this.featureCollection=featureCollection;
    this.properties=properties;
    this.features=featureCollection?.get("features");
    this.type = this.features?.get("type") as string;
    this.featureAssestId = this.features?.get("id") as string;
    this.geometry = this.features?.get("geometry") as ESObject;
    this.geometryType = this.geometry.get("type") as string;
    this.coordinatesInput = this.geometry.get("coordinates") as number[];
    this.coordinates = {
      latitude: this.coordinatesInput[0],
      longitude: this.coordinatesInput[1]
    };
  }
}
