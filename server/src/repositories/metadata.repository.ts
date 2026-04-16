import { Injectable } from '@nestjs/common';
import { BinaryField, DefaultReadTaskOptions, ExifTool, Tags } from 'exiftool-vendored';
import geotz from 'geo-tz';
import { LoggingRepository } from 'src/repositories/logging.repository';

interface ExifDuration {
  Value: number;
  Scale?: number;
}

type StringOrNumber = string | number;

type TagsWithWrongTypes =
  | 'FocalLength'
  | 'Duration'
  | 'Description'
  | 'ImageDescription'
  | 'RegionInfo'
  | 'TagsList'
  | 'Keywords'
  | 'HierarchicalSubject'
  | 'ISO';

export interface ImmichTags extends Omit<Tags, TagsWithWrongTypes> {
  ContentIdentifier?: string;
  MotionPhoto?: number;
  MotionPhotoVersion?: number;
  MotionPhotoPresentationTimestampUs?: number;
  MediaGroupUUID?: string;
  ImagePixelDepth?: string;
  FocalLength?: number;
  Duration?: number | string | ExifDuration;
  EmbeddedVideoType?: string;
  EmbeddedVideoFile?: BinaryField;
  MotionPhotoVideo?: BinaryField;
  TagsList?: StringOrNumber[];
  HierarchicalSubject?: StringOrNumber[];
  Keywords?: StringOrNumber | StringOrNumber[];
  ISO?: number | number[];

  // Type is wrong, can also be number.
  Description?: StringOrNumber;
  ImageDescription?: StringOrNumber;

  // Extended properties for image regions, such as faces
  RegionInfo?: {
    AppliedToDimensions: {
      W: number;
      H: number;
      Unit: string;
    };
    RegionList: {
      Area: {
        // (X,Y) // center of the rectangle
        X: number;
        Y: number;
        W: number;
        H: number;
        Unit: string;
      };
      Rotation?: number;
      Type?: string;
      Name?: string;
    }[];
  };

  Device?: {
    Manufacturer?: string;
    ModelName?: string;
  };

  AndroidMake?: string;
  AndroidModel?: string;
  DeviceManufacturer?: string;
  DeviceModelName?: string;
}

@Injectable()
export class MetadataRepository {
  private static readonly defaultReadArgs = ['-fast', '-api', 'largefilesupport=1'];

  private exiftool = new ExifTool({
    defaultVideosToUTC: true,
    backfillTimezones: true,
    inferTimezoneFromDatestamps: true,
    inferTimezoneFromTimeStamp: true,
    useMWG: true,
    numericTags: [...DefaultReadTaskOptions.numericTags, 'FocalLength', 'FileSize'],
    /* eslint unicorn/no-array-callback-reference: off, unicorn/no-array-method-this-argument: off */
    geoTz: (lat, lon) => geotz.find(lat, lon)[0],
    geolocation: false,
    // Enable exiftool LFS to parse metadata for files larger than 2GB.
    readArgs: MetadataRepository.defaultReadArgs,
    writeArgs: ['-api', 'largefilesupport=1', '-overwrite_original'],
    taskTimeoutMillis: 2 * 60 * 1000,
  });

  constructor(private logger: LoggingRepository) {
    this.logger.setContext(MetadataRepository.name);
  }

  setMaxConcurrency(concurrency: number) {
    this.exiftool.batchCluster.setMaxProcs(concurrency);
  }

  async teardown() {
    await this.exiftool.end();
  }

  async readTags(path: string): Promise<ImmichTags> {
    const readArgs = MetadataRepository.defaultReadArgs;

    const startedAt = Date.now();
    this.logger.log(`[metadata.readTags] start path=${path} args=${readArgs.join(' ')}`);
    const slowReadWarning = setTimeout(() => {
      this.logger.warn(
        `[metadata.readTags] still-running path=${path} elapsed=${Date.now() - startedAt}ms args=${readArgs.join(' ')}`,
      );
    }, 5000);

    try {
      const tags = (await this.exiftool.read(path, { readArgs })) as ImmichTags;
      this.logger.log(
        `[metadata.readTags] done path=${path} elapsed=${Date.now() - startedAt}ms tags=${Object.keys(tags).length}`,
      );

      return tags;
    } catch (error) {
      const stack = error instanceof Error ? error.stack : undefined;
      this.logger.warn(`Error reading exif data (${path}): ${error}${stack ? `\n${stack}` : ''}`);
      this.logger.log(`[metadata.readTags] failed path=${path} elapsed=${Date.now() - startedAt}ms`);
      return {};
    } finally {
      clearTimeout(slowReadWarning);
    }
  }

  async extractBinaryTag(path: string, tagName: string): Promise<Buffer> {
    const startedAt = Date.now();
    this.logger.log(`[metadata.extractBinaryTag] start path=${path} tag=${tagName}`);

    try {
      const buffer = await this.exiftool.extractBinaryTagToBuffer(tagName, path);
      this.logger.log(
        `[metadata.extractBinaryTag] done path=${path} tag=${tagName} elapsed=${Date.now() - startedAt}ms bytes=${buffer.byteLength}`,
      );

      return buffer;
    } catch (error) {
      const stack = error instanceof Error ? error.stack : undefined;
      this.logger.warn(`Error extracting binary exif tag (${path}, ${tagName}): ${error}${stack ? `\n${stack}` : ''}`);
      this.logger.log(`[metadata.extractBinaryTag] failed path=${path} tag=${tagName} elapsed=${Date.now() - startedAt}ms`);
      throw error;
    }
  }

  async writeTags(path: string, tags: Partial<Tags>): Promise<void> {
    // If exiftool assigns a field with ^= instead of =, empty values will be written too.
    // Since exiftool-vendored doesn't support an option for this, we append the ^ to the name of the tag instead.
    // https://exiftool.org/exiftool_pod.html#:~:text=is%20used%20to%20write%20an%20empty%20string
    const tagsToWrite = Object.fromEntries(Object.entries(tags).map(([key, value]) => [`${key}^`, value]));
    try {
      await this.exiftool.write(path, tagsToWrite);
    } catch (error) {
      this.logger.warn(`Error writing exif data (${path}): ${error}`);
    }
  }
}
