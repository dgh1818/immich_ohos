import { BadRequestException, Injectable, InternalServerErrorException, NotFoundException } from '@nestjs/common';
import { extname } from 'node:path';
import sanitize from 'sanitize-filename';
import { StorageCore } from 'src/cores/storage.core';
import { Asset, AssetFile, Exif } from 'src/database';
import {
  AssetBulkUploadCheckResponseDto,
  AssetMediaResponseDto,
  AssetMediaStatus,
  AssetRejectReason,
  AssetUploadAction,
  CheckExistingAssetsResponseDto,
} from 'src/dtos/asset-media-response.dto';
import {
  AssetBulkUploadCheckDto,
  AssetMediaCreateDto,
  AssetMediaOptionsDto,
  AssetMediaReplaceDto,
  AssetMediaSize,
  CheckExistingAssetsDto,
  UploadFieldName,
} from 'src/dtos/asset-media.dto';
import { AuthDto } from 'src/dtos/auth.dto';
import {
  AssetFileType,
  AssetPathType,
  AssetStatus,
  AssetType,
  AssetVisibility,
  CacheControl,
  ImageFormat,
  JobName,
  Permission,
  StorageFolder,
} from 'src/enum';
import { AuthRequest } from 'src/middleware/auth.guard';
import { BaseService } from 'src/services/base.service';
import { UploadFile, UploadRequest } from 'src/types';
import { requireUploadAccess } from 'src/utils/access';
import { asUploadRequest, getAssetFiles, onBeforeLink } from 'src/utils/asset.util';
import { isAssetChecksumConstraint } from 'src/utils/database';
import { getFilenameExtension, getFileNameWithoutExtension, ImmichFileResponse } from 'src/utils/file';
import { encodeIsoGainmapJpeg, extractLegacyGainmap } from 'src/utils/hdr-gainmap';
import { mimeTypes } from 'src/utils/mime-types';
import { fromChecksum } from 'src/utils/request';

export interface AssetMediaRedirectResponse {
  targetSize: AssetMediaSize | 'original';
}

@Injectable()
export class AssetMediaService extends BaseService {
  async getUploadAssetIdByChecksum(auth: AuthDto, checksum?: string): Promise<AssetMediaResponseDto | undefined> {
    if (!checksum) {
      return;
    }

    const assetId = await this.assetRepository.getUploadAssetIdByChecksum(auth.user.id, fromChecksum(checksum));
    if (!assetId) {
      return;
    }

    return { id: assetId, status: AssetMediaStatus.DUPLICATE };
  }

  canUploadFile({ auth, fieldName, file, body }: UploadRequest): true {
    requireUploadAccess(auth);

    const filename = body.filename || file.originalName;

    switch (fieldName) {
      case UploadFieldName.ASSET_DATA: {
        if (mimeTypes.isAsset(filename)) {
          return true;
        }
        break;
      }

      case UploadFieldName.SIDECAR_DATA: {
        if (mimeTypes.isSidecar(filename)) {
          return true;
        }
        break;
      }

      case UploadFieldName.PROFILE_DATA: {
        if (mimeTypes.isProfile(filename)) {
          return true;
        }
        break;
      }
    }

    this.logger.error(`Unsupported file type ${filename}`);
    throw new BadRequestException(`Unsupported file type ${filename}`);
  }

  getUploadFilename({ auth, fieldName, file, body }: UploadRequest): string {
    requireUploadAccess(auth);

    const extension = extname(body.filename || file.originalName);

    const lookup = {
      [UploadFieldName.ASSET_DATA]: extension,
      [UploadFieldName.SIDECAR_DATA]: '.xmp',
      [UploadFieldName.PROFILE_DATA]: extension,
    };

    return sanitize(`${file.uuid}${lookup[fieldName]}`);
  }

  getUploadFolder({ auth, fieldName, file }: UploadRequest): string {
    auth = requireUploadAccess(auth);

    let folder = StorageCore.getNestedFolder(StorageFolder.Upload, auth.user.id, file.uuid);
    if (fieldName === UploadFieldName.PROFILE_DATA) {
      folder = StorageCore.getFolderLocation(StorageFolder.Profile, auth.user.id);
    }

    this.storageRepository.mkdirSync(folder);

    return folder;
  }

  async onUploadError(request: AuthRequest, file: Express.Multer.File) {
    const uploadFilename = this.getUploadFilename(asUploadRequest(request, file));
    const uploadFolder = this.getUploadFolder(asUploadRequest(request, file));
    const uploadPath = `${uploadFolder}/${uploadFilename}`;

    await this.jobRepository.queue({ name: JobName.FileDelete, data: { files: [uploadPath] } });
  }

  async uploadAsset(
    auth: AuthDto,
    dto: AssetMediaCreateDto,
    file: UploadFile,
    sidecarFile?: UploadFile,
  ): Promise<AssetMediaResponseDto> {
    try {
      await this.requireAccess({
        auth,
        permission: Permission.AssetUpload,
        // do not need an id here, but the interface requires it
        ids: [auth.user.id],
      });

      this.requireQuota(auth, file.size);

      if (dto.livePhotoVideoId) {
        await onBeforeLink(
          { asset: this.assetRepository, event: this.eventRepository },
          { userId: auth.user.id, livePhotoVideoId: dto.livePhotoVideoId },
        );
      }
      const asset = await this.create(auth.user.id, dto, file, sidecarFile);

      await this.userRepository.updateUsage(auth.user.id, file.size);

      return { id: asset.id, status: AssetMediaStatus.CREATED };
    } catch (error: any) {
      return this.handleUploadError(error, auth, file, sidecarFile);
    }
  }

  async replaceAsset(
    auth: AuthDto,
    id: string,
    dto: AssetMediaReplaceDto,
    file: UploadFile,
    sidecarFile?: UploadFile,
  ): Promise<AssetMediaResponseDto> {
    try {
      await this.requireAccess({ auth, permission: Permission.AssetUpdate, ids: [id] });
      const asset = await this.assetRepository.getById(id);

      if (!asset) {
        throw new Error('Asset not found');
      }

      this.requireQuota(auth, file.size);

      await this.replaceFileData(asset.id, dto, file, sidecarFile?.originalPath);

      // Next, create a backup copy of the existing record. The db record has already been updated above,
      // but the local variable holds the original file data paths.
      const copiedPhoto = await this.createCopy(asset);
      // and immediate trash it
      await this.assetRepository.updateAll([copiedPhoto.id], { deletedAt: new Date(), status: AssetStatus.Trashed });
      await this.eventRepository.emit('AssetTrash', { assetId: copiedPhoto.id, userId: auth.user.id });

      await this.userRepository.updateUsage(auth.user.id, file.size);

      return { status: AssetMediaStatus.REPLACED, id: copiedPhoto.id };
    } catch (error: any) {
      return this.handleUploadError(error, auth, file, sidecarFile);
    }
  }

  async downloadOriginal(auth: AuthDto, id: string): Promise<ImmichFileResponse> {
    await this.requireAccess({ auth, permission: Permission.AssetDownload, ids: [id] });

    const asset = await this.findOrFail(id);

    const cuvaPath = await this.getCuvaIsoPath(asset);
    if (cuvaPath) {
      return new ImmichFileResponse({
        path: cuvaPath,
        fileName: asset.originalFileName,
        contentType: mimeTypes.lookup(cuvaPath),
        cacheControl: CacheControl.PrivateWithCache,
      });
    }

    return new ImmichFileResponse({
      path: asset.originalPath,
      fileName: asset.originalFileName,
      contentType: mimeTypes.lookup(asset.originalPath),
      cacheControl: CacheControl.PrivateWithCache,
    });
  }

  async viewThumbnail(
    auth: AuthDto,
    id: string,
    dto: AssetMediaOptionsDto,
  ): Promise<ImmichFileResponse | AssetMediaRedirectResponse> {
    await this.requireAccess({ auth, permission: Permission.AssetView, ids: [id] });

    const asset = await this.findOrFail(id);
    const size = dto.size ?? AssetMediaSize.THUMBNAIL;

    const { thumbnailFile, previewFile, fullsizeFile } = getAssetFiles(asset.files ?? []);
    let filepath = previewFile?.path;
    if (size === AssetMediaSize.THUMBNAIL && thumbnailFile) {
      filepath = thumbnailFile.path;
    } else if (size === AssetMediaSize.FULLSIZE) {
      if (mimeTypes.isWebSupportedImage(asset.originalPath)) {
        // use original file for web supported images
        return { targetSize: 'original' };
      }
      if (!fullsizeFile) {
        // downgrade to preview if fullsize is not available.
        // e.g. disabled or not yet (re)generated
        return { targetSize: AssetMediaSize.PREVIEW };
      }
      filepath = fullsizeFile.path;
    }

    if (!filepath) {
      throw new NotFoundException('Asset media not found');
    }
    let fileName = getFileNameWithoutExtension(asset.originalFileName);
    fileName += `_${size}`;
    fileName += getFilenameExtension(filepath);

    return new ImmichFileResponse({
      fileName,
      path: filepath,
      contentType: mimeTypes.lookup(filepath),
      cacheControl: CacheControl.PrivateWithCache,
    });
  }

  async playbackVideo(auth: AuthDto, id: string): Promise<ImmichFileResponse> {
    await this.requireAccess({ auth, permission: Permission.AssetView, ids: [id] });

    const asset = await this.findOrFail(id);

    if (asset.type !== AssetType.Video) {
      throw new BadRequestException('Asset is not a video');
    }

    const filepath = asset.encodedVideoPath || asset.originalPath;

    return new ImmichFileResponse({
      path: filepath,
      contentType: mimeTypes.lookup(filepath),
      cacheControl: CacheControl.PrivateWithCache,
    });
  }

  async checkExistingAssets(
    auth: AuthDto,
    checkExistingAssetsDto: CheckExistingAssetsDto,
  ): Promise<CheckExistingAssetsResponseDto> {
    const existingIds = await this.assetRepository.getByDeviceIds(
      auth.user.id,
      checkExistingAssetsDto.deviceId,
      checkExistingAssetsDto.deviceAssetIds,
    );
    return { existingIds };
  }

  async bulkUploadCheck(auth: AuthDto, dto: AssetBulkUploadCheckDto): Promise<AssetBulkUploadCheckResponseDto> {
    const checksums: Buffer[] = dto.assets.map((asset) => fromChecksum(asset.checksum));
    const results = await this.assetRepository.getByChecksums(auth.user.id, checksums);
    const checksumMap: Record<string, { id: string; isTrashed: boolean }> = {};

    for (const { id, deletedAt, checksum } of results) {
      checksumMap[checksum.toString('hex')] = { id, isTrashed: !!deletedAt };
    }

    return {
      results: dto.assets.map(({ id, checksum }) => {
        const duplicate = checksumMap[fromChecksum(checksum).toString('hex')];
        if (duplicate) {
          return {
            id,
            action: AssetUploadAction.REJECT,
            reason: AssetRejectReason.DUPLICATE,
            assetId: duplicate.id,
            isTrashed: duplicate.isTrashed,
          };
        }

        return {
          id,
          action: AssetUploadAction.ACCEPT,
        };
      }),
    };
  }

  private async handleUploadError(
    error: any,
    auth: AuthDto,
    file: UploadFile,
    sidecarFile?: UploadFile,
  ): Promise<AssetMediaResponseDto> {
    // clean up files
    await this.jobRepository.queue({
      name: JobName.FileDelete,
      data: { files: [file.originalPath, sidecarFile?.originalPath] },
    });

    // handle duplicates with a success response
    if (isAssetChecksumConstraint(error)) {
      const duplicateId = await this.assetRepository.getUploadAssetIdByChecksum(auth.user.id, file.checksum);
      if (!duplicateId) {
        this.logger.error(`Error locating duplicate for checksum constraint`);
        throw new InternalServerErrorException();
      }
      return { status: AssetMediaStatus.DUPLICATE, id: duplicateId };
    }

    this.logger.error(`Error uploading file ${error}`, error?.stack);
    throw error;
  }

  /**
   * Updates the specified assetId to the specified photo data file properties: checksum, path,
   * timestamps, deviceIds, and sidecar. Derived properties like: faces, smart search info, etc
   * are UNTOUCHED. The photo data files modification times on the filesysytem are updated to
   * the specified timestamps. The exif db record is upserted, and then A METADATA_EXTRACTION
   * job is queued to update these derived properties.
   */
  private async replaceFileData(
    assetId: string,
    dto: AssetMediaReplaceDto,
    file: UploadFile,
    sidecarPath?: string,
  ): Promise<void> {
    await this.assetRepository.update({
      id: assetId,

      checksum: file.checksum,
      originalPath: file.originalPath,
      type: mimeTypes.assetType(file.originalPath),
      originalFileName: file.originalName,

      deviceAssetId: dto.deviceAssetId,
      deviceId: dto.deviceId,
      fileCreatedAt: dto.fileCreatedAt,
      fileModifiedAt: dto.fileModifiedAt,
      localDateTime: dto.fileCreatedAt,
      duration: dto.duration || null,

      livePhotoVideoId: null,
    });

    await (sidecarPath
      ? this.assetRepository.upsertFile({ assetId, type: AssetFileType.Sidecar, path: sidecarPath })
      : this.assetRepository.deleteFile({ assetId, type: AssetFileType.Sidecar }));

    await this.storageRepository.utimes(file.originalPath, new Date(), new Date(dto.fileModifiedAt));
    await this.assetRepository.upsertExif(
      { assetId, fileSizeInByte: file.size },
      { lockedPropertiesBehavior: 'override' },
    );
    await this.jobRepository.queue({
      name: JobName.AssetExtractMetadata,
      data: { id: assetId, source: 'upload' },
    });
  }

  /**
   * Create a 'shallow' copy of the specified asset record creating a new asset record in the database.
   * Uses only vital properties excluding things like: stacks, faces, smart search info, etc,
   * and then queues a METADATA_EXTRACTION job.
   */
  private async createCopy(asset: Omit<Asset, 'id'>) {
    const created = await this.assetRepository.create({
      ownerId: asset.ownerId,
      originalPath: asset.originalPath,
      originalFileName: asset.originalFileName,
      libraryId: asset.libraryId,
      deviceAssetId: asset.deviceAssetId,
      deviceId: asset.deviceId,
      type: asset.type,
      checksum: asset.checksum,
      fileCreatedAt: asset.fileCreatedAt,
      localDateTime: asset.localDateTime,
      fileModifiedAt: asset.fileModifiedAt,
      livePhotoVideoId: asset.livePhotoVideoId,
    });

    const { size } = await this.storageRepository.stat(created.originalPath);
    await this.assetRepository.upsertExif(
      { assetId: created.id, fileSizeInByte: size },
      { lockedPropertiesBehavior: 'override' },
    );
    await this.jobRepository.queue({ name: JobName.AssetExtractMetadata, data: { id: created.id, source: 'copy' } });
    return created;
  }

  private async create(ownerId: string, dto: AssetMediaCreateDto, file: UploadFile, sidecarFile?: UploadFile) {
    const asset = await this.assetRepository.create({
      ownerId,
      libraryId: null,

      checksum: file.checksum,
      originalPath: file.originalPath,

      deviceAssetId: dto.deviceAssetId,
      deviceId: dto.deviceId,

      fileCreatedAt: dto.fileCreatedAt,
      fileModifiedAt: dto.fileModifiedAt,
      localDateTime: dto.fileCreatedAt,

      type: mimeTypes.assetType(file.originalPath),
      isFavorite: dto.isFavorite,
      duration: dto.duration || null,
      visibility: dto.visibility ?? AssetVisibility.Timeline,
      livePhotoVideoId: dto.livePhotoVideoId,
      originalFileName: dto.filename || file.originalName,
    });

    if (dto.metadata) {
      await this.assetRepository.upsertMetadata(asset.id, dto.metadata);
    }

    if (sidecarFile) {
      await this.assetRepository.upsertFile({
        assetId: asset.id,
        path: sidecarFile.originalPath,
        type: AssetFileType.Sidecar,
      });
      await this.storageRepository.utimes(sidecarFile.originalPath, new Date(), new Date(dto.fileModifiedAt));
    }
    await this.storageRepository.utimes(file.originalPath, new Date(), new Date(dto.fileModifiedAt));
    await this.assetRepository.upsertExif(
      { assetId: asset.id, fileSizeInByte: file.size },
      { lockedPropertiesBehavior: 'override' },
    );

    await this.eventRepository.emit('AssetCreate', { asset });

    await this.jobRepository.queue({ name: JobName.AssetExtractMetadata, data: { id: asset.id, source: 'upload' } });

    return asset;
  }

  private requireQuota(auth: AuthDto, size: number) {
    if (auth.user.quotaSizeInBytes !== null && auth.user.quotaSizeInBytes < auth.user.quotaUsageInBytes + size) {
      throw new BadRequestException('Quota has been exceeded!');
    }
  }

  private async getCuvaIsoPath(
    asset: Asset & { files?: AssetFile[]; exifInfo?: Exif | null },
  ): Promise<string | null> {
    if (mimeTypes.lookup(asset.originalPath) !== 'image/jpeg') {
      return null;
    }

    const fullsizePath = StorageCore.getImagePath(asset, AssetPathType.FullSize, ImageFormat.Jpeg);
    if (await this.storageRepository.checkFileExists(fullsizePath)) {
      const { fullsizeFile } = getAssetFiles(asset.files ?? []);
      if (!fullsizeFile || fullsizeFile.path !== fullsizePath) {
        await this.assetRepository.upsertFile({ assetId: asset.id, type: AssetFileType.FullSize, path: fullsizePath });
      }
      return fullsizePath;
    }

    let source: Buffer;
    try {
      source = await this.storageRepository.readFile(asset.originalPath);
    } catch (error: any) {
      this.logger.debug(`Failed to read source image for ${asset.id}: ${error?.message ?? error}`);
      return null;
    }

    const firstE0 = source.indexOf(Buffer.from([0xff, 0xd8, 0xff, 0xe0]));
    const secondE5 = firstE0 >= 0 ? source.indexOf(Buffer.from([0xff, 0xd8, 0xff, 0xe5]), firstE0 + 1) : -1;
    const secondEoi = secondE5 >= 0 ? source.indexOf(Buffer.from([0xff, 0xd9]), secondE5 + 2) : -1;
    const dumpAt = (offset: number, length: number) =>
      offset >= 0 ? source.subarray(offset, Math.min(offset + length, source.length)).toString('hex') : 'n/a';
    this.logger.error(
      `Legacy gainmap markers for ${asset.id}: firstE0=${firstE0}(${dumpAt(firstE0, 8)}) ` +
        `secondE5=${secondE5}(${dumpAt(secondE5, 8)}) secondEoi=${secondEoi}(${dumpAt(secondEoi, 4)})`,
    );

    const legacyGainmap = extractLegacyGainmap(source, { make: asset.exifInfo?.make ?? null });
    this.logger.error(
      `Legacy gainmap detect for ${asset.id}: ${legacyGainmap ? legacyGainmap.type : 'none'}`,
    );
    if (!legacyGainmap || legacyGainmap.type !== 'cuva') {
      return null;
    }

    try {
      this.storageCore.ensureFolders(fullsizePath);
      const isoBuffer = encodeIsoGainmapJpeg(legacyGainmap.sdrImage, legacyGainmap.gainmapImage, source);
      await this.storageRepository.createOrOverwriteFile(fullsizePath, isoBuffer);
      await this.assetRepository.upsertFile({ assetId: asset.id, type: AssetFileType.FullSize, path: fullsizePath });
      return fullsizePath;
    } catch (error: any) {
      this.logger.warn(`Failed to encode CUVA gainmap for ${asset.id}: ${error?.message ?? error}`);
      return null;
    }
  }

  private async findOrFail(id: string) {
    const asset = await this.assetRepository.getById(id, { files: true, exifInfo: true });
    if (!asset) {
      throw new NotFoundException('Asset not found');
    }

    return asset;
  }
}
