import { Injectable } from '@nestjs/common';
import handlebar from 'handlebars';
import { DateTime } from 'luxon';
import path from 'node:path';
import sanitize from 'sanitize-filename';
import { JOBS_ASSET_PAGINATION_SIZE } from 'src/constants';
import { StorageCore } from 'src/cores/storage.core';
import { OnEvent, OnJob } from 'src/decorators';
import { SystemConfigTemplateStorageOptionDto } from 'src/dtos/system-config.dto';
import {
  AssetFileType,
  AssetPathType,
  AssetType,
  DatabaseLock,
  ImmichWorker,
  JobName,
  JobStatus,
  QueueName,
  StorageFolder,
  SystemMetadataKey,
} from 'src/enum';
import { ArgOf } from 'src/repositories/event.repository';
import { BaseService } from 'src/services/base.service';
import { JobOf, StorageAsset, StorageTemplateMigrationFailure, StorageTemplateMigrationState } from 'src/types';
import { getAssetFile } from 'src/utils/asset.util';
import { getFilenameExtension, getLivePhotoMotionFilename } from 'src/utils/file';

const STORAGE_TEMPLATE_MIGRATION_FILE_TIMEOUT_MS = 3 * 60 * 1000;

const storageTokens = {
  secondOptions: ['s', 'ss', 'SSS'],
  minuteOptions: ['m', 'mm'],
  dayOptions: ['d', 'dd'],
  weekOptions: ['W', 'WW'],
  hourOptions: ['h', 'hh', 'H', 'HH'],
  yearOptions: ['y', 'yy'],
  monthOptions: ['M', 'MM', 'MMM', 'MMMM'],
};

const storagePresets = [
  '{{y}}/{{y}}-{{MM}}-{{dd}}/{{filename}}',
  '{{y}}/{{MM}}-{{dd}}/{{filename}}',
  '{{y}}/{{MMMM}}-{{dd}}/{{filename}}',
  '{{y}}/{{MM}}/{{filename}}',
  '{{y}}/{{#if album}}{{album}}{{else}}Other/{{MM}}{{/if}}/{{filename}}',
  '{{#if album}}{{album-startDate-y}}/{{album}}{{else}}{{y}}/Other/{{MM}}{{/if}}/{{filename}}',
  '{{y}}/{{MMM}}/{{filename}}',
  '{{y}}/{{MMMM}}/{{filename}}',
  '{{y}}/{{MM}}/{{dd}}/{{filename}}',
  '{{y}}/{{MMMM}}/{{dd}}/{{filename}}',
  '{{y}}/{{y}}-{{MM}}/{{y}}-{{MM}}-{{dd}}/{{filename}}',
  '{{y}}-{{MM}}-{{dd}}/{{filename}}',
  '{{y}}-{{MMM}}-{{dd}}/{{filename}}',
  '{{y}}-{{MMMM}}-{{dd}}/{{filename}}',
  '{{y}}/{{y}}-{{MM}}/{{filename}}',
  '{{y}}/{{y}}-{{WW}}/{{filename}}',
  '{{y}}/{{y}}-{{MM}}-{{dd}}/{{assetId}}',
  '{{y}}/{{y}}-{{MM}}/{{assetId}}',
  '{{y}}/{{y}}-{{WW}}/{{assetId}}',
  '{{album}}/{{filename}}',
  '{{make}}/{{model}}/{{lensModel}}/{{filename}}',
];

export interface MoveAssetMetadata {
  storageLabel: string | null;
  filename: string;
}

type StorageTemplateMigrationStage = 'resolve-template' | 'move-original' | 'move-sidecar';

interface MoveAssetStage {
  stage: StorageTemplateMigrationStage;
  targetPath?: string;
}

interface MoveAssetOptions {
  timeoutMs?: number;
  onStage?: (stage: MoveAssetStage) => Promise<void>;
}

type MoveAssetResult =
  | { success: true }
  | { success: false; failure: Omit<StorageTemplateMigrationFailure, 'attempts'> };

interface RenderMetadata {
  asset: StorageAsset;
  filename: string;
  extension: string;
  albumName: string | null;
  albumStartDate: Date | null;
  albumEndDate: Date | null;
  make: string | null;
  model: string | null;
  lensModel: string | null;
}

@Injectable()
export class StorageTemplateService extends BaseService {
  private _template: {
    compiled: HandlebarsTemplateDelegate<any>;
    raw: string;
    needsAlbum: boolean;
    needsAlbumMetadata: boolean;
  } | null = null;

  private get template() {
    if (!this._template) {
      throw new Error('Template not initialized');
    }
    return this._template;
  }

  @OnEvent({ name: 'ConfigInit' })
  onConfigInit({ newConfig }: ArgOf<'ConfigInit'>) {
    const template = newConfig.storageTemplate.template;
    if (!this._template || template !== this.template.raw) {
      this.logger.debug(`Compiling new storage template: ${template}`);
      this._template = this.compile(template);
    }
  }

  @OnEvent({ name: 'ConfigInit', workers: [ImmichWorker.Microservices] })
  async queueMigrationOnUpgrade({ newConfig }: ArgOf<'ConfigInit'>) {
    if (!newConfig.storageTemplate.enabled) {
      return;
    }

    const state = await this.systemMetadataRepository.get(SystemMetadataKey.StorageTemplateMigration);
    if (state?.queuedAt) {
      return;
    }

    this.logger.log('Queueing one-time storage template migration');
    await this.jobRepository.queue({ name: JobName.StorageTemplateMigration });
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, {
      queuedAt: new Date().toISOString(),
    });
  }

  @OnEvent({ name: 'ConfigUpdate', server: true })
  onConfigUpdate({ newConfig }: ArgOf<'ConfigUpdate'>) {
    this.onConfigInit({ newConfig });
  }

  @OnEvent({ name: 'ConfigValidate' })
  onConfigValidate({ newConfig }: ArgOf<'ConfigValidate'>) {
    try {
      const { compiled } = this.compile(newConfig.storageTemplate.template);
      this.render(compiled, {
        asset: {
          fileCreatedAt: new Date(),
          originalPath: '/upload/test/IMG_123.jpg',
          type: AssetType.Image,
          id: 'd587e44b-f8c0-4832-9ba3-43268bbf5d4e',
        } as StorageAsset,
        filename: 'IMG_123',
        extension: 'jpg',
        albumName: 'album',
        albumStartDate: new Date(),
        albumEndDate: new Date(),
        make: 'FUJIFILM',
        model: 'X-T50',
        lensModel: 'XF27mm F2.8 R WR',
      });
    } catch (error) {
      this.logger.warn(`Storage template validation failed: ${JSON.stringify(error)}`);
      throw new Error('Invalid storage template', { cause: error });
    }
  }

  getStorageTemplateOptions(): SystemConfigTemplateStorageOptionDto {
    return { ...storageTokens, presetOptions: storagePresets };
  }

  async getStorageTemplateMigrationState(): Promise<StorageTemplateMigrationState> {
    return this.getMigrationState();
  }

  async retryStorageTemplateMigrationFailures(): Promise<StorageTemplateMigrationState> {
    const state = await this.getMigrationState();
    const assetIds = [...new Set((state.failures ?? []).map((failure) => failure.retryAssetId ?? failure.assetId))];

    for (const id of assetIds) {
      await this.jobRepository.queue({ name: JobName.StorageTemplateMigrationSingle, data: { id } });
    }

    state.failures = [];
    state.failed = 0;
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
    return state;
  }

  async clearStorageTemplateMigrationFailures(): Promise<StorageTemplateMigrationState> {
    const state = await this.getMigrationState();
    state.failures = [];
    state.failed = 0;
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
    return state;
  }

  @OnEvent({ name: 'AssetMetadataExtracted' })
  async onAssetMetadataExtracted({ source, assetId }: ArgOf<'AssetMetadataExtracted'>) {
    await this.jobRepository.queue({ name: JobName.StorageTemplateMigrationSingle, data: { source, id: assetId } });
  }

  @OnJob({ name: JobName.StorageTemplateMigrationSingle, queue: QueueName.StorageTemplateMigration })
  async handleMigrationSingle({ id }: JobOf<JobName.StorageTemplateMigrationSingle>): Promise<JobStatus> {
    const config = await this.getConfig({ withCache: true });
    const isStorageTemplateEnabled = config.storageTemplate.enabled;
    if (!isStorageTemplateEnabled) {
      return JobStatus.Skipped;
    }

    const asset = await this.assetJobRepository.getForStorageTemplateJob(id);
    if (!asset) {
      return JobStatus.Failed;
    }

    const user = await this.userRepository.get(asset.ownerId, {});
    const storageLabel = user?.storageLabel || null;
    const filename = asset.originalFileName || asset.id;
    const result = await this.moveAsset(asset, { storageLabel, filename }, undefined, {
      timeoutMs: STORAGE_TEMPLATE_MIGRATION_FILE_TIMEOUT_MS,
    });
    if (!result.success) {
      await this.recordSingleMigrationFailure(result.failure);
      return JobStatus.Failed;
    }
    await this.clearSingleMigrationFailure(asset.id);

    // move motion part of live photo
    if (asset.livePhotoVideoId) {
      const livePhotoVideo = await this.assetJobRepository.getForStorageTemplateJob(asset.livePhotoVideoId, {
        includeHidden: true,
      });
      if (!livePhotoVideo) {
        return JobStatus.Failed;
      }
      const motionFilename = getLivePhotoMotionFilename(filename, livePhotoVideo.originalPath);
      const motionResult = await this.moveAsset(livePhotoVideo, { storageLabel, filename: motionFilename }, asset, {
        timeoutMs: STORAGE_TEMPLATE_MIGRATION_FILE_TIMEOUT_MS,
      });
      if (!motionResult.success) {
        await this.recordSingleMigrationFailure({ ...motionResult.failure, retryAssetId: asset.id });
        return JobStatus.Failed;
      }
      await this.clearSingleMigrationFailure(livePhotoVideo.id);
    }
    return JobStatus.Success;
  }

  @OnJob({ name: JobName.StorageTemplateMigration, queue: QueueName.StorageTemplateMigration })
  async handleMigration(): Promise<JobStatus> {
    const { storageTemplate } = await this.getConfig({ withCache: true });
    const { enabled } = storageTemplate;
    if (!enabled) {
      this.logger.log('Storage template migration disabled, skipping');
      return JobStatus.Skipped;
    }

    await this.moveRepository.cleanMoveHistory();

    const currentState = await this.systemMetadataRepository.get(SystemMetadataKey.StorageTemplateMigration);
    const resume = !currentState?.completedAt && !!currentState?.afterId;
    const state: StorageTemplateMigrationState = {
      queuedAt: currentState?.queuedAt ?? new Date().toISOString(),
      startedAt: resume ? currentState?.startedAt : new Date().toISOString(),
      scanned: resume ? (currentState?.scanned ?? 0) : 0,
      failed: currentState?.failed ?? 0,
      failures: currentState?.failures ?? [],
      afterId: resume ? currentState?.afterId : undefined,
    };
    let afterId = state.afterId;

    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
    this.logger.log(
      resume
        ? `Resuming storage template migration from ${state.scanned} scanned`
        : 'Starting storage template migration',
    );

    const users = await this.userRepository.getList();

    while (true) {
      const assets = await this.assetJobRepository.getStorageTemplateJobPage({
        afterId,
        limit: JOBS_ASSET_PAGINATION_SIZE,
      });

      if (assets.length === 0) {
        break;
      }

      afterId = assets.at(-1)?.id;

      for (const asset of assets) {
        state.scanned = (state.scanned ?? 0) + 1;

        try {
          const user = users.find((user) => user.id === asset.ownerId);
          const storageLabel = user?.storageLabel || null;
          const filename = asset.originalFileName || asset.id;
          const result = await this.moveAsset(asset, { storageLabel, filename }, undefined, {
            timeoutMs: STORAGE_TEMPLATE_MIGRATION_FILE_TIMEOUT_MS,
            onStage: (stage) => this.setMigrationCurrent(state, asset, stage),
          });
          if (!result.success) {
            this.addMigrationFailure(state, result.failure);
            await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
            continue;
          }

          // move motion part of live photo
          if (asset.livePhotoVideoId) {
            const livePhotoVideo = await this.assetJobRepository.getForStorageTemplateJob(asset.livePhotoVideoId, {
              includeHidden: true,
            });
            if (livePhotoVideo) {
              const motionFilename = getLivePhotoMotionFilename(filename, livePhotoVideo.originalPath);
              const motionResult = await this.moveAsset(
                livePhotoVideo,
                { storageLabel, filename: motionFilename },
                asset,
                {
                  timeoutMs: STORAGE_TEMPLATE_MIGRATION_FILE_TIMEOUT_MS,
                  onStage: (stage) => this.setMigrationCurrent(state, livePhotoVideo, stage),
                },
              );
              if (!motionResult.success) {
                this.addMigrationFailure(state, { ...motionResult.failure, retryAssetId: asset.id });
                await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
                continue;
              }
              this.clearMigrationFailure(state, livePhotoVideo.id);
            }
          }
          this.clearMigrationFailure(state, asset.id);
        } catch (error: any) {
          const failure = this.toMigrationFailure(asset, 'resolve-template', asset.originalPath, undefined, error);
          this.addMigrationFailure(state, failure);
          await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
        }
      }

      state.afterId = afterId;
      await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
      this.logger.log(`Storage template migration progress: ${state.scanned} scanned, ${state.failed} failed`);
    }

    this.logger.debug('Cleaning up empty directories...');
    const libraryFolder = StorageCore.getBaseFolder(StorageFolder.Library);
    await this.storageRepository.removeEmptyDirs(libraryFolder);

    state.completedAt = new Date().toISOString();
    delete state.afterId;
    delete state.current;
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
    this.logger.log(`Finished storage template migration: ${state.scanned} scanned, ${state.failed} failed`);

    return JobStatus.Success;
  }

  @OnEvent({ name: 'AssetDelete' })
  async handleMoveHistoryCleanup({ assetId }: ArgOf<'AssetDelete'>) {
    this.logger.debug(`Cleaning up move history for asset ${assetId}`);
    await this.moveRepository.cleanMoveHistorySingle(assetId);
  }

  async moveAsset(
    asset: StorageAsset,
    metadata: MoveAssetMetadata,
    stillPhoto?: StorageAsset,
    options: MoveAssetOptions = {},
  ): Promise<MoveAssetResult> {
    if (asset.isExternal || StorageCore.isAndroidMotionPath(asset.originalPath)) {
      // External assets are not affected by storage template
      // TODO: shouldn't this only apply to external assets?
      return { success: true };
    }

    return this.databaseRepository.withLock(DatabaseLock.StorageTemplateMigration, async () => {
      const { id, originalPath, checksum, fileSizeInByte } = asset;
      const oldPath = originalPath;
      let stage: StorageTemplateMigrationStage = 'resolve-template';
      let newPath: string | undefined;

      try {
        await options.onStage?.({ stage });
        newPath = await this.getTemplatePath(asset, metadata, stillPhoto);

        if (!fileSizeInByte) {
          const error = new Error(`Asset ${id} missing exif info`);
          return { success: false, failure: this.toMigrationFailure(asset, 'move-original', oldPath, newPath, error) };
        }

        stage = 'move-original';
        await options.onStage?.({ stage, targetPath: newPath });
        const movedOriginal = await this.storageCore.moveFile({
          entityId: id,
          pathType: AssetPathType.Original,
          oldPath,
          newPath,
          timeoutMs: options.timeoutMs,
          assetInfo: { sizeInBytes: fileSizeInByte, checksum },
        });
        if (!movedOriginal) {
          const error = new Error('Original file move did not complete');
          return { success: false, failure: this.toMigrationFailure(asset, 'move-original', oldPath, newPath, error) };
        }

        const sidecarPath = getAssetFile(asset.files, AssetFileType.Sidecar, { isEdited: false })?.path;
        if (sidecarPath) {
          const sidecarTargetPath = `${newPath}.xmp`;
          stage = 'move-sidecar';
          await options.onStage?.({ stage, targetPath: sidecarTargetPath });
          const movedSidecar = await this.storageCore.moveFile({
            entityId: id,
            pathType: AssetFileType.Sidecar,
            oldPath: sidecarPath,
            newPath: sidecarTargetPath,
            timeoutMs: options.timeoutMs,
          });
          if (!movedSidecar) {
            const error = new Error('Sidecar file move did not complete');
            return {
              success: false,
              failure: this.toMigrationFailure(asset, 'move-sidecar', sidecarPath, sidecarTargetPath, error),
            };
          }
        }
        return { success: true };
      } catch (error: any) {
        return { success: false, failure: this.toMigrationFailure(asset, stage, oldPath, newPath, error) };
      }
    });
  }

  private async getMigrationState(): Promise<StorageTemplateMigrationState> {
    const state = await this.systemMetadataRepository.get(SystemMetadataKey.StorageTemplateMigration);
    return {
      ...state,
      queuedAt: state?.queuedAt ?? new Date().toISOString(),
      failed: state?.failed ?? state?.failures?.length ?? 0,
      failures: state?.failures ?? [],
    };
  }

  private async recordSingleMigrationFailure(failure: Omit<StorageTemplateMigrationFailure, 'attempts'>) {
    const state = await this.getMigrationState();
    this.addMigrationFailure(state, failure);
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
  }

  private async clearSingleMigrationFailure(assetId: string) {
    const state = await this.getMigrationState();
    this.clearMigrationFailure(state, assetId);
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
  }

  private addMigrationFailure(
    state: StorageTemplateMigrationState,
    failure: Omit<StorageTemplateMigrationFailure, 'attempts'>,
  ) {
    const failures = state.failures ?? [];
    const existing = failures.find(
      (item) =>
        item.assetId === failure.assetId && item.stage === failure.stage && item.originalPath === failure.originalPath,
    );

    if (existing) {
      existing.targetPath = failure.targetPath;
      existing.reason = failure.reason;
      existing.failedAt = failure.failedAt;
      existing.timedOut = failure.timedOut;
      existing.attempts++;
    } else {
      failures.push({ ...failure, attempts: 1 });
    }

    state.failures = failures;
    state.failed = failures.length;

    this.logger.error(`Storage template migration failed for asset ${failure.assetId}: ${failure.reason}`, {
      id: failure.assetId,
      stage: failure.stage,
      oldPath: failure.originalPath,
      newPath: failure.targetPath,
      retryAssetId: failure.retryAssetId,
      timedOut: failure.timedOut,
    });
  }

  private clearMigrationFailure(state: StorageTemplateMigrationState, assetId: string) {
    state.failures = (state.failures ?? []).filter((failure) => failure.assetId !== assetId);
    state.failed = state.failures.length;
  }

  private async setMigrationCurrent(
    state: StorageTemplateMigrationState,
    asset: StorageAsset,
    { stage, targetPath }: MoveAssetStage,
  ) {
    state.current = {
      assetId: asset.id,
      originalPath: asset.originalPath,
      targetPath,
      stage,
      startedAt: new Date().toISOString(),
    };
    await this.systemMetadataRepository.set(SystemMetadataKey.StorageTemplateMigration, state);
  }

  private toMigrationFailure(
    asset: StorageAsset,
    stage: StorageTemplateMigrationStage,
    originalPath: string,
    targetPath: string | undefined,
    error: Error | any,
  ): Omit<StorageTemplateMigrationFailure, 'attempts'> {
    const reason = this.getErrorMessage(error);
    const name = error instanceof Error ? error.name : undefined;
    return {
      assetId: asset.id,
      originalPath,
      targetPath,
      stage,
      reason,
      failedAt: new Date().toISOString(),
      timedOut: name === 'TimeoutError' || name === 'AbortError' || reason.includes('timed out'),
    };
  }

  private getErrorMessage(error: Error | any) {
    return error instanceof Error ? error.message : String(error);
  }

  private async getTemplatePath(
    asset: StorageAsset,
    metadata: MoveAssetMetadata,
    stillPhoto?: StorageAsset,
  ): Promise<string> {
    const { storageLabel, filename } = metadata;

    try {
      const filenameWithoutExtension = path.basename(filename, getFilenameExtension(filename));

      const source = asset.originalPath;
      let extension = getFilenameExtension(source).split('.').pop() as string;
      const sanitized = sanitize(path.basename(filenameWithoutExtension, `.${extension}`));
      extension = extension?.toLowerCase();
      const rootPath = StorageCore.getLibraryFolder({ id: asset.ownerId, storageLabel });

      switch (extension) {
        case 'jpeg':
        case 'jpe': {
          extension = 'jpg';
          break;
        }
        case 'tif': {
          extension = 'tiff';
          break;
        }
        case '3gpp': {
          extension = '3gp';
          break;
        }
        case 'mpeg':
        case 'mpe': {
          extension = 'mpg';
          break;
        }
        case 'm2ts':
        case 'm2t': {
          extension = 'mts';
          break;
        }
      }

      let albumName = null;
      let albumStartDate = null;
      let albumEndDate = null;
      const assetForMetadata = stillPhoto || asset;

      if (this.template.needsAlbum) {
        // For motion videos, use the still photo's album information since motion videos
        // don't have album metadata attached directly
        const albums = await this.albumRepository.getByAssetId(assetForMetadata.ownerId, assetForMetadata.id);
        const album = albums?.[0];
        if (album) {
          albumName = album.albumName || null;

          if (this.template.needsAlbumMetadata) {
            const [metadata] = await this.albumRepository.getMetadataForIds([album.id]);
            albumStartDate = metadata?.startDate || null;
            albumEndDate = metadata?.endDate || null;
          }
        }
      }

      // For motion videos that are part of live photos, use the still photo's date
      // to ensure both parts end up in the same folder
      const storagePath = this.render(this.template.compiled, {
        asset: assetForMetadata,
        filename: sanitized,
        extension,
        albumName,
        albumStartDate,
        albumEndDate,
        make: assetForMetadata.make,
        model: assetForMetadata.model,
        lensModel: assetForMetadata.lensModel,
      });
      const fullPath = path.normalize(path.join(rootPath, storagePath));
      let destination = `${fullPath}.${extension}`;

      if (!fullPath.startsWith(rootPath)) {
        this.logger.warn(`Skipped attempt to access an invalid path: ${fullPath}. Path should start with ${rootPath}`);
        return source;
      }

      if (source === destination) {
        return source;
      }

      /**
       * In case of migrating duplicate filename to a new path, we need to check if it is already migrated
       * Due to the mechanism of appending +1, +2, +3, etc to the filename
       *
       * Example:
       * Source = upload/abc/def/FullSizeRender+7.heic
       * Expected Destination = upload/abc/def/FullSizeRender.heic
       *
       * The file is already at the correct location, but since there are other FullSizeRender.heic files in the
       * destination, it was renamed to FullSizeRender+7.heic.
       *
       * The lines below will be used to check if the differences between the source and destination is only the
       * +7 suffix, and if so, it will be considered as already migrated.
       */
      if (source.startsWith(fullPath) && source.endsWith(`.${extension}`)) {
        const diff = source.replace(fullPath, '').replace(`.${extension}`, '');
        const hasDuplicationAnnotation = /^\+\d+$/.test(diff);
        if (hasDuplicationAnnotation) {
          return source;
        }
      }

      let duplicateCount = 0;

      while (true) {
        const isExists = await this.storageRepository.checkFileExists(destination);
        if (!isExists) {
          break;
        }

        duplicateCount++;
        destination = `${fullPath}+${duplicateCount}.${extension}`;
      }

      return destination;
    } catch (error: any) {
      this.logger.error(`Unable to get template path for ${filename}: ${error}`);
      return asset.originalPath;
    }
  }

  private compile(template: string) {
    return {
      raw: template,
      compiled: handlebar.compile(template, { knownHelpers: undefined, strict: true }),
      needsAlbum: template.includes('album'),
      needsAlbumMetadata: template.includes('album-startDate') || template.includes('album-endDate'),
    };
  }

  private render(template: HandlebarsTemplateDelegate<any>, options: RenderMetadata) {
    const { filename, extension, asset, albumName, albumStartDate, albumEndDate, make, model, lensModel } = options;
    const substitutions: Record<string, string> = {
      filename,
      ext: extension,
      filetype: asset.type == AssetType.Image ? 'IMG' : 'VID',
      filetypefull: asset.type == AssetType.Image ? 'IMAGE' : 'VIDEO',
      assetId: asset.id,
      assetIdShort: asset.id.slice(-12),
      //just throw into the root if it doesn't belong to an album
      album: (albumName && sanitize(albumName.replaceAll(/\.+/g, ''))) || '',
      make: make ?? '',
      model: model ?? '',
      lensModel: lensModel ?? '',
    };

    const dt = DateTime.fromJSDate(asset.fileCreatedAt);

    for (const token of Object.values(storageTokens).flat()) {
      substitutions[token] = dt.toFormat(token);
      if (albumName) {
        // Album date tokens are rendered in the server time zone to match storage template datetime behavior.
        substitutions['album-startDate-' + token] = albumStartDate
          ? DateTime.fromJSDate(albumStartDate).toFormat(token)
          : '';
        substitutions['album-endDate-' + token] = albumEndDate ? DateTime.fromJSDate(albumEndDate).toFormat(token) : '';
      }
    }

    return template(substitutions).replaceAll(/\/{2,}/gm, '/');
  }
}
