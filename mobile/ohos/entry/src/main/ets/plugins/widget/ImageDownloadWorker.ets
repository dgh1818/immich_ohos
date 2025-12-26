import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';

import { ImmichAPI } from './ImmichAPI';
import {
  DEFAULT_ALBUM_ID,
  FAVORITES_ALBUM_ID,
  WidgetFormData,
  WidgetState,
  WidgetType,
  assetDeeplink,
  imageFilename,
  loadServerConfig,
  loadWidgetConfig,
  SearchFilters,
  WidgetEntry,
} from './model/Model';

const DEFAULT_DEEPLINK = 'immich://';

interface ImageDownloadResult {
  imgName: string;
  formImages: Record<string, number>;
  file: fs.File;
  filePath: string;
}

export async function updateWidgetForm(
  context: common.Context,
  formId: string,
  widgetType: WidgetType,
): Promise<void> {
  console.error(`[WidgetUpdate] updateWidgetForm start formId=${formId} type=${widgetType}`);
  if (!formId) {
    console.error('[WidgetUpdate] missing formId');
    return;
  }

  const config = loadServerConfig(context);
  if (!config) {
    console.error('[WidgetUpdate] no server config -> LOG_IN');
    const formImages: Record<string, number> = {};
    const data = buildFormData('', DEFAULT_DEEPLINK, WidgetState.LOG_IN, '', formImages, false);
    await updateForm(formId, data);
    scheduleNextRefresh(context, formId);
    return;
  }
  console.error(`[WidgetUpdate] server config ok endpoint=${config.serverEndpoint}`);

  const api = new ImmichAPI(config);
  let imageResult: ImageDownloadResult | null = null;
  try {
    const entry = await fetchEntry(context, api, widgetType, formId);
    console.error(`[WidgetUpdate] fetched entry assetId=${entry.assetId} subtitle=${entry.subtitle}`);
    imageResult = await downloadImage(context, api, entry.assetId, formId);
    console.error(
      `[WidgetUpdate] downloaded image path=${imageResult.filePath} imgName=${imageResult.imgName}`,
    );
    const data = buildFormData(
      entry.subtitle,
      entry.deeplink,
      WidgetState.SUCCESS,
      imageResult.imgName,
      imageResult.formImages,
      true,
    );
    await updateForm(formId, data);
  } catch (error) {
    console.error(`[WidgetUpdate] update failed error=${error}`);
    const formImages: Record<string, number> = {};
    const data = buildFormData('', DEFAULT_DEEPLINK, WidgetState.ERROR, '', formImages, false);
    await updateForm(formId, data);
  } finally {
    if (imageResult) {
      try {
        fs.closeSync(imageResult.file);
      } catch (error) {
        console.error(`[WidgetUpdate] close image file failed error=${error}`);
      }
    }
  }
  scheduleNextRefresh(context, formId);
}

function buildFormData(
  text: string,
  deeplink: string,
  state: WidgetState,
  imgName: string,
  formImages: Record<string, number>,
  loaded: boolean,
): WidgetFormData {
  const data: WidgetFormData = {
    text,
    loaded,
    imgName,
    formImages,
    deeplink,
    state,
  };
  return data;
}

async function updateForm(formId: string, data: WidgetFormData): Promise<void> {
  console.error(
    `[WidgetUpdate] updateForm state=${data.state} loaded=${data.loaded} imgName=${data.imgName} text=${data.text}`,
  );
  await formProvider.updateForm(formId, formBindingData.createFormBindingData(data));
}

function scheduleNextRefresh(context: common.Context, formId: string): void {
  if (!formId) {
    return;
  }
  const config = loadWidgetConfig(context, formId);
  const refreshMinutes = config.refreshMinutes;
  if (!refreshMinutes || refreshMinutes <= 0) {
    console.error(`[WidgetUpdate] skip schedule refreshMinutes=${refreshMinutes}`);
    return;
  }
  try {
    formProvider.setFormNextRefreshTime(formId, refreshMinutes, (err: BusinessError) => {
      if (err) {
        console.error(
          `[WidgetUpdate] setFormNextRefreshTime failed code=${err.code} message=${err.message}`,
        );
        return;
      }
      console.error(`[WidgetUpdate] setFormNextRefreshTime ok minutes=${refreshMinutes}`);
    });
  } catch (error) {
    const err = error as BusinessError;
    console.error(
      `[WidgetUpdate] setFormNextRefreshTime threw code=${err.code} message=${err.message}`,
    );
  }
}

async function fetchEntry(
  context: common.Context,
  api: ImmichAPI,
  widgetType: WidgetType,
  formId: string,
): Promise<WidgetEntry> {
  if (widgetType === WidgetType.MEMORIES) {
    return await fetchMemoryEntry(context, api, formId);
  }
  return await fetchRandomEntry(context, api, formId);
}

async function fetchRandomEntry(
  context: common.Context,
  api: ImmichAPI,
  formId: string,
): Promise<WidgetEntry> {
  const config = loadWidgetConfig(context, formId);
  const filters: SearchFilters = { type: 'IMAGE', size: 1 };
  let subtitle = config.showAlbumName ? config.albumName : '';
  console.error(
    `[WidgetUpdate] fetchRandomEntry formId=${formId} albumId=${config.albumId} albumName=${config.albumName} show=${config.showAlbumName}`,
  );

  if (config.albumId === FAVORITES_ALBUM_ID) {
    filters.isFavorite = true;
  } else if (config.albumId && config.albumId !== DEFAULT_ALBUM_ID) {
    filters.albumIds = [config.albumId];
  }

  let assets = await api.fetchSearchResults(filters);
  console.error(`[WidgetUpdate] fetchRandomEntry results count=${assets?.length ?? 0}`);
  if (!assets || assets.length === 0) {
    if (config.albumId && config.albumId !== DEFAULT_ALBUM_ID) {
      assets = await api.fetchSearchResults({ type: 'IMAGE', size: 1 });
      console.error(`[WidgetUpdate] fallback fetchRandomEntry count=${assets?.length ?? 0}`);
      subtitle = '';
    }
  }
  if (!assets || assets.length === 0) {
    throw new Error('No assets returned');
  }

  const asset = assets[0];
  return {
    assetId: asset.id,
    subtitle,
    deeplink: assetDeeplink(asset.id),
  };
}

async function fetchMemoryEntry(
  context: common.Context,
  api: ImmichAPI,
  formId: string,
): Promise<WidgetEntry> {
  const today = new Date();
  const memories = await api.fetchMemory(today);
  console.error(`[WidgetUpdate] fetchMemoryEntry count=${memories?.length ?? 0}`);

  if (memories && memories.length > 0) {
    const memory = memories[Math.floor(Math.random() * memories.length)];
    const asset = memory.assets[Math.floor(Math.random() * memory.assets.length)];
    const yearDiff = today.getFullYear() - memory.data.year;
    const subtitle = `${yearDiff} ${yearDiff === 1 ? 'year' : 'years'} ago`;
    return {
      assetId: asset.id,
      subtitle,
      deeplink: assetDeeplink(asset.id),
    };
  }

  return await fetchRandomEntry(context, api, formId);
}

async function downloadImage(
  context: common.Context,
  api: ImmichAPI,
  assetId: string,
  formId: string,
): Promise<ImageDownloadResult> {
  console.error(`[WidgetUpdate] downloadImage assetId=${assetId} formId=${formId}`);
  const buffer = await api.fetchImage(assetId);
  console.error(`[WidgetUpdate] downloaded image bytes=${buffer.byteLength}`);
  const baseDir = context.getApplicationContext().cacheDir;
  const cacheDir = `${baseDir}/widget`;
  try {
    fs.mkdirSync(cacheDir);
  } catch (_) {
    // ignore if exists
  }
  const filePath = `${cacheDir}/${imageFilename(formId)}`;
  const file = fs.openSync(filePath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  try {
    fs.truncateSync(file.fd, 0);
    fs.writeSync(file.fd, buffer);
    fs.truncateSync(file.fd, buffer.byteLength);
  } catch (e) {
    fs.closeSync(file);
    throw e as Error;
  }
  try {
    const stat = fs.statSync(filePath);
    console.error(`[WidgetUpdate] downloaded image fileSize=${stat.size}`);
  } catch (error) {
    console.error(`[WidgetUpdate] failed to stat image path=${filePath} error=${error}`);
  }
  const imgName = `${formId}_${Date.now()}`;
  const formImages: Record<string, number> = {};
  formImages[imgName] = file.fd;
  return {
    imgName,
    formImages,
    file,
    filePath,
  };
}
