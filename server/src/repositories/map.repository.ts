import { Inject, Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { getName } from 'i18n-iso-countries';
import { createReadStream, existsSync } from 'node:fs';
import { readFile } from 'node:fs/promises';
import readLine from 'node:readline';
import { citiesFile, resourcePaths } from 'src/constants';
import { AssetEntity } from 'src/entities/asset.entity';
import { GeodataPlacesEntity } from 'src/entities/geodata-places.entity';
import { NaturalEarthCountriesEntity } from 'src/entities/natural-earth-countries.entity';
import { SystemMetadataKey } from 'src/entities/system-metadata.entity';
import { ILoggerRepository } from 'src/interfaces/logger.interface';
import {
  GeoPoint,
  IMapRepository,
  MapMarker,
  MapMarkerSearchOptions,
  ReverseGeocodeResult,
} from 'src/interfaces/map.interface';
import { ISystemMetadataRepository } from 'src/interfaces/system-metadata.interface';
import { OptionalBetween } from 'src/utils/database';
import { Instrumentation } from 'src/utils/instrumentation';
import { DataSource, In, IsNull, Not, QueryRunner, Repository } from 'typeorm';
import { QueryDeepPartialEntity } from 'typeorm/query-builder/QueryPartialEntity.js';

@Instrumentation()
@Injectable()
export class MapRepository implements IMapRepository {
  constructor(
    @InjectRepository(AssetEntity) private assetRepository: Repository<AssetEntity>,
    @InjectRepository(GeodataPlacesEntity) private geodataPlacesRepository: Repository<GeodataPlacesEntity>,
    @InjectRepository(NaturalEarthCountriesEntity)
    private naturalEarthCountriesRepository: Repository<NaturalEarthCountriesEntity>,
    @InjectDataSource() private dataSource: DataSource,
    @Inject(ISystemMetadataRepository) private metadataRepository: ISystemMetadataRepository,
    @Inject(ILoggerRepository) private logger: ILoggerRepository,
  ) {
    this.logger.setContext(MapRepository.name);
  }

  async init(): Promise<void> {
    this.logger.log('Initializing metadata repository');
    const geodataDate = await readFile(resourcePaths.geodata.dateFile, 'utf8');

    // TODO move to service init
    const geocodingMetadata = await this.metadataRepository.get(SystemMetadataKey.REVERSE_GEOCODING_STATE);
    if (geocodingMetadata?.lastUpdate === geodataDate) {
      return;
    }

    await this.importGeodata();
    await this.importNaturalEarthCountries();

    await this.metadataRepository.set(SystemMetadataKey.REVERSE_GEOCODING_STATE, {
      lastUpdate: geodataDate,
      lastImportFileName: citiesFile,
    });

    this.logger.log('Geodata import completed');
  }

  async getMapMarkers(
    ownerIds: string[],
    albumIds: string[],
    options: MapMarkerSearchOptions = {},
  ): Promise<MapMarker[]> {
    const { isArchived, isFavorite, fileCreatedAfter, fileCreatedBefore } = options;

    const where = {
      isVisible: true,
      isArchived,
      exifInfo: {
        latitude: Not(IsNull()),
        longitude: Not(IsNull()),
      },
      isFavorite,
      fileCreatedAt: OptionalBetween(fileCreatedAfter, fileCreatedBefore),
    };

    const assets = await this.assetRepository.find({
      select: {
        id: true,
        exifInfo: {
          city: true,
          state: true,
          country: true,
          latitude: true,
          longitude: true,
        },
      },
      where: [
        { ...where, ownerId: In([...ownerIds]) },
        { ...where, albums: { id: In([...albumIds]) } },
      ],
      relations: {
        exifInfo: true,
      },
      order: {
        fileCreatedAt: 'DESC',
      },
    });

    return assets.map((asset) => ({
      id: asset.id,
      lat: asset.exifInfo!.latitude!,
      lon: asset.exifInfo!.longitude!,
      city: asset.exifInfo!.city,
      state: asset.exifInfo!.state,
      country: asset.exifInfo!.country,
    }));
  }

  async fetchStyle(url: string) {
    try {
      const response = await fetch(url);

      if (!response.ok) {
        throw new Error(`Failed to fetch data from ${url} with status ${response.status}: ${await response.text()}`);
      }

      return response.json();
    } catch (error) {
      throw new Error(`Failed to fetch data from ${url}: ${error}`);
    }
  }

  async reverseGeocodeWithPetalmap(point: GeoPoint): Promise<ReverseGeocodeResult> {
    this.logger.debug(`Request: ${point.latitude},${point.longitude}`);
    // var isCooldown = false;
    // var cooldownEndTime = 0;
    // var isProcessing = false;

    // let ERROR_COOLDOWN: Record<string, number> = {
    //   '010037': 5000,  // 5秒冷却
    //   '010006': 60000, // 60秒冷却
    //   'default': 1000  // 默认1秒
    // };

    // read key list from env,AMAP_GEOCODE_KEYS, then random select one key
    const keys = process.env.PETALMAP_GEOCODE_KEYS?.split(',') ?? [];
    const key = keys[Math.floor(Math.random() * keys.length)];
    const url = `https://siteapi.cloud.huawei.com/mapApi/v1/siteService/reverseGeocode`;

    const headers = {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${key}`, // 如果 API 要求 token 放在 Authorization
      // 你可以按实际情况加入更多 header，比如 cookie 或自定义头
    };

    const body = JSON.stringify({
      location: {
        lng: point.longitude,
        lat: point.latitude,
      },
      language: 'zh-CN',
      radius: 10,
    });

    const response = await fetch(`${url}`, {
      method: 'POST',
      headers: headers,
      body: body,
    });

    if (!response.ok) {
      this.logger.error(`Request failed with status ${response.status}`);
      return { country: null, state: null, city: null };
    }

    const data = await response.json();
    const country = data.sites[0].address.country;
    const state = data.sites[0].address.adminArea;
    let city = data.sites[0].address.city;
    if (city == '' || city == null) {
      city = data.sites[0].address.adminArea;
    }

    let district = data.sites[0].address.tertiaryAdminArea;
    let town = data.sites[0].address.subLocality;
    let address = data.sites[0].formatAddress;

    if ((district = '')) {
      district = null;
    }
    if ((town = '')) {
      town = null;
    }
    this.logger.log(`address: ${address}`);
    this.logger.log(`tertiaryAdminArea: ${district}`);
    this.logger.log(`subLocality: ${town}`);
    if (state == city) {
      city = town;
      //district = town;
    }

    //return { country, state, city, district, address };

    return { country, state, city };
  }

  async reverseGeocodeWithAmap(point: GeoPoint): Promise<ReverseGeocodeResult> {
    this.logger.debug(`Request: ${point.latitude},${point.longitude}`);

    // read key list from env,AMAP_GEOCODE_KEYS, then random select one key
    const keys = process.env.AMAP_GEOCODE_KEYS?.split(',') ?? [];
    const key = keys[Math.floor(Math.random() * keys.length)];
    //const url = `https://locationapi.cloud.huawei.com`;
    const url = `https://restapi.amap.com/v3/geocode/regeo`;

    const params = {
      key: key,
      location: `${point.longitude},${point.latitude}`,
      radius: '1000',
      extensions: 'base',
      roadlevel: '0',
    };

    const response = await fetch(`${url}?${new URLSearchParams(params)}`);
    if (!response.ok) {
      this.logger.error(`Request failed with status ${response.status}`);
      return { country: null, state: null, city: null };
    }

    const data = await response.json();
    const country = data.regeocode.addressComponent.country;
    const state = data.regeocode.addressComponent.province;
    let city = data.regeocode.addressComponent.city;
    if (city == '' || city == null) {
      city = data.regeocode.addressComponent.province;
    }
    const district = data.regeocode.addressComponent.district;

    const address = data.regeocode.formatted_address;
    this.logger.log(`address: ${address}`);

    return { country, state, city };
  }

  async reverseGeocode(point: GeoPoint): Promise<ReverseGeocodeResult | null> {
    this.logger.debug(`Request: ${point.latitude},${point.longitude}`);

    if (process.env.GEOCODE_WITH_AMAP === 'true') {
      this.logger.log('Using Amap for reverse geocoding');
      return this.reverseGeocodeWithAmap(point);
    }

    if (process.env.GEOCODE_WITH_PETALMAP === 'true') {
      this.logger.log('Using PetalMAP for reverse geocoding');
      return this.reverseGeocodeWithPetalmap(point);
    }

    const response = await this.geodataPlacesRepository
      .createQueryBuilder('geoplaces')
      .where('earth_box(ll_to_earth(:latitude, :longitude), 25000) @> "earthCoord"', point)
      .orderBy('earth_distance(ll_to_earth(:latitude, :longitude), "earthCoord")')
      .limit(1)
      .getOne();

    if (response) {
      this.logger.verbose(`Raw: ${JSON.stringify(response, null, 2)}`);

      const { countryCode, name: city, admin1Name } = response;
      const country = getName(countryCode, 'en') ?? null;
      const state = admin1Name;

      return { country, state, city };
    }

    this.logger.warn(
      `Response from database for reverse geocoding latitude: ${point.latitude}, longitude: ${point.longitude} was null`,
    );

    const ne_response = await this.naturalEarthCountriesRepository
      .createQueryBuilder('naturalearth_countries')
      .where('coordinates @> point (:longitude, :latitude)', point)
      .limit(1)
      .getOne();

    if (!ne_response) {
      this.logger.warn(
        `Response from database for natural earth reverse geocoding latitude: ${point.latitude}, longitude: ${point.longitude} was null`,
      );

      return null;
    }

    this.logger.verbose(`Raw: ${JSON.stringify(ne_response, ['id', 'admin', 'admin_a3', 'type'], 2)}`);

    const { admin_a3 } = ne_response;
    const country = getName(admin_a3, 'en') ?? null;
    const state = null;
    const city = null;

    return { country, state, city };
  }

  private transformCoordinatesToPolygon(coordinates: number[][][]): string {
    const pointsString = coordinates.map((point) => `(${point[0]},${point[1]})`).join(', ');
    return `(${pointsString})`;
  }

  private async importNaturalEarthCountries() {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();

    try {
      await queryRunner.startTransaction();
      await queryRunner.manager.clear(NaturalEarthCountriesEntity);

      const fileContent = await readFile(resourcePaths.geodata.naturalEarthCountriesPath, 'utf8');
      const geoJSONData = JSON.parse(fileContent);

      if (geoJSONData.type !== 'FeatureCollection' || !Array.isArray(geoJSONData.features)) {
        this.logger.fatal('Invalid GeoJSON FeatureCollection');
        return;
      }

      for await (const feature of geoJSONData.features) {
        for (const polygon of feature.geometry.coordinates) {
          const featureRecord = new NaturalEarthCountriesEntity();
          featureRecord.admin = feature.properties.ADMIN;
          featureRecord.admin_a3 = feature.properties.ADM0_A3;
          featureRecord.type = feature.properties.TYPE;

          if (feature.geometry.type === 'MultiPolygon') {
            featureRecord.coordinates = this.transformCoordinatesToPolygon(polygon[0]);
            await queryRunner.manager.save(featureRecord);
          } else if (feature.geometry.type === 'Polygon') {
            featureRecord.coordinates = this.transformCoordinatesToPolygon(polygon);
            await queryRunner.manager.save(featureRecord);
            break;
          }
        }
      }

      await queryRunner.commitTransaction();
    } catch (error) {
      this.logger.fatal('Error importing natural earth country data', error);
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  private async importGeodata() {
    const queryRunner = this.dataSource.createQueryRunner();
    await queryRunner.connect();

    const admin1 = await this.loadAdmin(resourcePaths.geodata.admin1);
    const admin2 = await this.loadAdmin(resourcePaths.geodata.admin2);

    try {
      await queryRunner.startTransaction();

      await queryRunner.manager.clear(GeodataPlacesEntity);
      await this.loadCities500(queryRunner, admin1, admin2);

      await queryRunner.commitTransaction();
    } catch (error) {
      this.logger.fatal('Error importing geodata', error);
      await queryRunner.rollbackTransaction();
      throw error;
    } finally {
      await queryRunner.release();
    }
  }

  private async loadGeodataToTableFromFile(
    queryRunner: QueryRunner,
    lineToEntityMapper: (lineSplit: string[]) => GeodataPlacesEntity,
    filePath: string,
    options?: { entityFilter?: (linesplit: string[]) => boolean },
  ) {
    const _entityFilter = options?.entityFilter ?? (() => true);
    if (!existsSync(filePath)) {
      this.logger.error(`Geodata file ${filePath} not found`);
      throw new Error(`Geodata file ${filePath} not found`);
    }

    const input = createReadStream(filePath);
    let bufferGeodata: QueryDeepPartialEntity<GeodataPlacesEntity>[] = [];
    const lineReader = readLine.createInterface({ input });

    for await (const line of lineReader) {
      const lineSplit = line.split('\t');
      if (!_entityFilter(lineSplit)) {
        continue;
      }
      const geoData = lineToEntityMapper(lineSplit);
      bufferGeodata.push(geoData);
      if (bufferGeodata.length > 1000) {
        await queryRunner.manager.upsert(GeodataPlacesEntity, bufferGeodata, ['id']);
        bufferGeodata = [];
      }
    }
    await queryRunner.manager.upsert(GeodataPlacesEntity, bufferGeodata, ['id']);
  }

  private async loadCities500(
    queryRunner: QueryRunner,
    admin1Map: Map<string, string>,
    admin2Map: Map<string, string>,
  ) {
    await this.loadGeodataToTableFromFile(
      queryRunner,
      (lineSplit: string[]) =>
        this.geodataPlacesRepository.create({
          id: Number.parseInt(lineSplit[0]),
          name: lineSplit[1],
          alternateNames: lineSplit[3],
          latitude: Number.parseFloat(lineSplit[4]),
          longitude: Number.parseFloat(lineSplit[5]),
          countryCode: lineSplit[8],
          admin1Code: lineSplit[10],
          admin2Code: lineSplit[11],
          modificationDate: lineSplit[18],
          admin1Name: admin1Map.get(`${lineSplit[8]}.${lineSplit[10]}`),
          admin2Name: admin2Map.get(`${lineSplit[8]}.${lineSplit[10]}.${lineSplit[11]}`),
        }),
      resourcePaths.geodata.cities500,
      { entityFilter: (lineSplit) => lineSplit[7] != 'PPLX' },
    );
  }

  private async loadAdmin(filePath: string) {
    if (!existsSync(filePath)) {
      this.logger.error(`Geodata file ${filePath} not found`);
      throw new Error(`Geodata file ${filePath} not found`);
    }

    const input = createReadStream(filePath);
    const lineReader = readLine.createInterface({ input: input });

    const adminMap = new Map<string, string>();
    for await (const line of lineReader) {
      const lineSplit = line.split('\t');
      adminMap.set(lineSplit[0], lineSplit[1]);
    }

    return adminMap;
  }
}
