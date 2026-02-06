import formBindingData from '@ohos.app.form.formBindingData';
import formProvider from '@ohos.app.form.formProvider';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { fileIo as fs } from '@kit.CoreFileKit';

import { ImmichAPI } from './ImmichAPI';
import {
  DEFAULT_ALBUM_ID,
  DEFAULT_REFRESH_MINUTES,
  FAVORITES_ALBUM_ID,
  WidgetFormData,
  WidgetConfig,
  WidgetState,
  WidgetType,
  assetDeeplink,
  loadServerConfig,
  loadWidgetConfig,
  loadWidgetEntries,
  loadWidgetIndex,
  loadWidgetSlot,
  isWidgetAlbumOverride,
  SearchFilters,
  saveWidgetConfig,
  saveWidgetEntries,
  saveWidgetIndex,
  saveWidgetSlot,
  markWidgetAlbumOverride,
  WidgetEntry,
  WidgetImageEntry,
} from './model/Model';

const DEFAULT_DEEPLINK = 'immich://';
const MAX_WIDGET_IMAGES = 20;
const LOAD_MORE_COUNT = 1;

interface ImageDownloadResult {
  imgName: string;
  formImages: Record<string, number>;
  files: Array<fs.File>;
  entries: Array<WidgetImageEntry>;
  nextSlot: number;
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

  const widgetConfig = loadWidgetConfig(context, formId);
  const slideIntervalSeconds = widgetConfig.slideIntervalSeconds;
  const config = loadServerConfig(context);
  if (config) {
    await applyCachedFormData(context, formId, slideIntervalSeconds);
  }
  if (!config) {
    console.error('[WidgetUpdate] no server config -> LOG_IN');
    const formImages: Record<string, number> = {};
    const data = buildFormData(
      '',
      DEFAULT_DEEPLINK,
      WidgetState.LOG_IN,
      '',
      formImages,
      false,
      '[]',
      0,
      slideIntervalSeconds,
    );
    await updateForm(formId, data);
    saveWidgetEntries(context, formId, '[]');
    saveWidgetIndex(context, formId, 0);
    saveWidgetSlot(context, formId, 0);
    scheduleNextRefresh(context, formId);
    return;
  }
  console.error(`[WidgetUpdate] server config ok endpoint=${config.serverEndpoint}`);

  const api = new ImmichAPI(config, context.getApplicationContext());
  let imageResult: ImageDownloadResult | null = null;
  try {
    const entries = await fetchEntries(
      context,
      api,
      widgetType,
      formId,
      MAX_WIDGET_IMAGES,
      true,
    );
    console.error(`[WidgetUpdate] fetched entries count=${entries.length}`);
    imageResult = await downloadImages(context, api, entries, formId);
    const primaryEntry = imageResult.entries[0];
    const primaryText = primaryEntry?.text ?? '';
    const primaryDeeplink = primaryEntry?.deeplink ?? DEFAULT_DEEPLINK;
    const primaryImgName = primaryEntry?.imgName ?? '';
    const entriesJson = JSON.stringify(imageResult.entries);
    const storedEntries = parseEntriesJson(loadWidgetEntries(context, formId));
    const storedIndex = loadWidgetIndex(context, formId);
    let activeIndex = clampIndex(storedIndex, imageResult.entries.length);
    if (storedEntries.length > 0 && imageResult.entries.length > 0) {
      activeIndex = (activeIndex + 1) % imageResult.entries.length;
    }
    const data = buildFormData(
      primaryText,
      primaryDeeplink,
      WidgetState.SUCCESS,
      primaryImgName,
      imageResult.formImages,
      true,
      entriesJson,
      activeIndex,
      slideIntervalSeconds,
    );
    saveWidgetEntries(context, formId, entriesJson);
    saveWidgetIndex(context, formId, activeIndex);
    saveWidgetSlot(context, formId, imageResult.nextSlot);
    await updateForm(formId, data);
    cleanupStaleSlots(context, formId, storedEntries, imageResult.entries);
  } catch (error) {
    console.error(`[WidgetUpdate] update failed error=${error}`);
    const formImages: Record<string, number> = {};
    const data = buildFormData(
      '',
      DEFAULT_DEEPLINK,
      WidgetState.ERROR,
      '',
      formImages,
      false,
      '[]',
      0,
      slideIntervalSeconds,
    );
    await updateForm(formId, data);
    saveWidgetEntries(context, formId, '[]');
    saveWidgetIndex(context, formId, 0);
    saveWidgetSlot(context, formId, 0);
  } finally {
    if (imageResult) {
      for (const file of imageResult.files) {
        try {
          fs.closeSync(file);
        } catch (error) {
          console.error(`[WidgetUpdate] close image file failed error=${error}`);
        }
      }
    }
  }
  scheduleNextRefresh(context, formId);
}

export async function loadMoreWidgetImages(
  context: common.Context,
  formId: string,
  widgetType: WidgetType,
  currentImgName: string,
  currentIndex: number,
): Promise<void> {
  console.error(`[WidgetUpdate] loadMoreWidgetImages start formId=${formId} index=${currentIndex}`);
  if (!formId) {
    console.error('[WidgetUpdate] loadMoreWidgetImages missing formId');
    return;
  }
  const widgetConfig = loadWidgetConfig(context, formId);
  const slideIntervalSeconds = widgetConfig.slideIntervalSeconds;
  const config = loadServerConfig(context);
  if (!config) {
    console.error('[WidgetUpdate] loadMoreWidgetImages no server config');
    const formImages: Record<string, number> = {};
    const data = buildFormData(
      '',
      DEFAULT_DEEPLINK,
      WidgetState.LOG_IN,
      '',
      formImages,
      false,
      '[]',
      0,
      slideIntervalSeconds,
    );
    await updateForm(formId, data);
    return;
  }

  const storedEntries = parseEntriesJson(loadWidgetEntries(context, formId));
  if (storedEntries.length === 0) {
    console.error('[WidgetUpdate] loadMoreWidgetImages empty entries -> full refresh');
    await updateWidgetForm(context, formId, widgetType);
    return;
  }

  const api = new ImmichAPI(config, context.getApplicationContext());
  let files: Array<fs.File> = [];
  try {
    const newEntries = await fetchEntries(
      context,
      api,
      widgetType,
      formId,
      LOAD_MORE_COUNT,
      false,
    );
    if (newEntries.length === 0) {
      console.error('[WidgetUpdate] loadMoreWidgetImages no new entries');
      return;
    }

    const unusedSlot = findUnusedSlot(formId, storedEntries);
    let slot =
      unusedSlot !== null ? unusedSlot : loadWidgetSlot(context, formId) % MAX_WIDGET_IMAGES;
    const currentSlot = imageSlotFromName(formId, currentImgName);
    if (currentSlot !== null && slot === currentSlot) {
      slot = (slot + 1) % MAX_WIDGET_IMAGES;
    }
    await downloadImageToSlot(context, api, newEntries[0], formId, slot);
    const nextSlot = (slot + 1) % MAX_WIDGET_IMAGES;
    saveWidgetSlot(context, formId, nextSlot);

    const appended: WidgetImageEntry = {
      imgName: imageNameForSlot(formId, slot),
      text: newEntries[0].subtitle ?? '',
      deeplink: newEntries[0].deeplink ?? DEFAULT_DEEPLINK,
    };

    let merged = storedEntries.filter((entry) => entry.imgName !== appended.imgName);
    merged.push(appended);
    if (merged.length > MAX_WIDGET_IMAGES) {
      merged = merged.slice(merged.length - MAX_WIDGET_IMAGES);
    }

    const activeIndex = resolveActiveIndex(merged, currentImgName, currentIndex);
    const entriesJson = JSON.stringify(merged);
    const openResult = openEntryFiles(context, merged, formId);
    files = openResult.files;
    const primary = merged[0];
    const data = buildFormData(
      primary?.text ?? '',
      primary?.deeplink ?? DEFAULT_DEEPLINK,
      WidgetState.SUCCESS,
      primary?.imgName ?? '',
      openResult.formImages,
      true,
      entriesJson,
      activeIndex,
      slideIntervalSeconds,
    );
    saveWidgetEntries(context, formId, entriesJson);
    saveWidgetIndex(context, formId, activeIndex);
    await updateForm(formId, data);
    cleanupStaleSlots(context, formId, storedEntries, merged);
  } catch (error) {
    console.error(`[WidgetUpdate] loadMoreWidgetImages failed error=${error}`);
  } finally {
    for (const file of files) {
      try {
        fs.closeSync(file);
      } catch (error) {
        console.error(`[WidgetUpdate] loadMoreWidgetImages close file failed error=${error}`);
      }
    }
  }
}

function buildFormData(
  text: string,
  deeplink: string,
  state: WidgetState,
  imgName: string,
  formImages: Record<string, number>,
  loaded: boolean,
  entriesJson: string,
  activeIndex: number,
  slideIntervalSeconds: number,
): WidgetFormData {
  const data: WidgetFormData = {
    text,
    loaded,
    imgName,
    formImages,
    deeplink,
    entriesJson,
    activeIndex,
    slideIntervalSeconds,
    state,
  };
  return data;
}

async function applyCachedFormData(
  context: common.Context,
  formId: string,
  slideIntervalSeconds: number,
): Promise<boolean> {
  const storedEntries = parseEntriesJson(loadWidgetEntries(context, formId));
  if (storedEntries.length === 0) {
    return false;
  }

  const openResult = openEntryFiles(context, storedEntries, formId);
  if (Object.keys(openResult.formImages).length === 0) {
    for (const file of openResult.files) {
      try {
        fs.closeSync(file);
      } catch (_) {
        // ignore close error
      }
    }
    return false;
  }

  const storedIndex = loadWidgetIndex(context, formId);
  const activeIndex = clampIndex(storedIndex, storedEntries.length);
  const primary = storedEntries[0];
  const entriesJson = JSON.stringify(storedEntries);
  const data = buildFormData(
    primary?.text ?? '',
    primary?.deeplink ?? DEFAULT_DEEPLINK,
    WidgetState.SUCCESS,
    primary?.imgName ?? '',
    openResult.formImages,
    true,
    entriesJson,
    activeIndex,
    slideIntervalSeconds,
  );
  await updateForm(formId, data);

  for (const file of openResult.files) {
    try {
      fs.closeSync(file);
    } catch (_) {
      // ignore close error
    }
  }

  return true;
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
  const refreshMinutes = DEFAULT_REFRESH_MINUTES;
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

function clampIndex(index: number, length: number): number {
  if (!Number.isFinite(index) || length <= 0) {
    return 0;
  }
  if (index < 0) {
    return 0;
  }
  if (index >= length) {
    return length - 1;
  }
  return index;
}

function resolveActiveIndex(
  entries: Array<WidgetImageEntry>,
  currentImgName: string,
  fallbackIndex: number,
): number {
  if (entries.length === 0) {
    return 0;
  }
  if (currentImgName) {
    const idx = entries.findIndex((entry) => entry.imgName === currentImgName);
    if (idx >= 0) {
      return idx;
    }
  }
  return clampIndex(fallbackIndex, entries.length);
}

function parseEntriesJson(raw: string): Array<WidgetImageEntry> {
  if (!raw) {
    return [];
  }
  try {
    const parsed = JSON.parse(raw) as Array<WidgetImageEntry>;
    if (!Array.isArray(parsed)) {
      return [];
    }
    return parsed.filter(
      (entry) => !!entry && typeof entry.imgName === 'string' && entry.imgName.length > 0,
    );
  } catch (_) {
    return [];
  }
}

async function downloadImageToSlot(
  context: common.Context,
  api: ImmichAPI,
  entry: WidgetEntry,
  formId: string,
  slot: number,
): Promise<void> {
  console.error(`[WidgetUpdate] downloadImage slot=${slot} assetId=${entry.assetId} formId=${formId}`);
  const buffer = await api.fetchImage(entry.assetId);
  console.error(`[WidgetUpdate] downloaded image bytes=${buffer.byteLength} slot=${slot}`);
  writeBufferToSlot(context, formId, slot, buffer);
}

interface OpenFilesResult {
  formImages: Record<string, number>;
  files: Array<fs.File>;
}

function openEntryFiles(
  context: common.Context,
  entries: Array<WidgetImageEntry>,
  formId: string,
): OpenFilesResult {
  const formImages: Record<string, number> = {};
  const files: Array<fs.File> = [];
  const baseDir = context.getApplicationContext().cacheDir;
  const cacheDir = `${baseDir}/widget`;
  for (const entry of entries) {
    const slot = imageSlotFromName(formId, entry.imgName);
    if (slot === null) {
      continue;
    }
    const filePath = `${cacheDir}/${imageFilenameForSlot(formId, slot)}`;
    try {
      const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE);
      formImages[entry.imgName] = file.fd;
      files.push(file);
    } catch (error) {
      console.error(`[WidgetUpdate] openEntryFiles failed imgName=${entry.imgName} error=${error}`);
    }
  }
  return { formImages, files };
}

function imageSlotFromName(formId: string, imgName: string): number | null {
  if (!formId || !imgName) {
    return null;
  }
  const prefix = `widget_${formId}_`;
  if (!imgName.startsWith(prefix)) {
    return null;
  }
  const raw = imgName.substring(prefix.length);
  const parsed = parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return parsed;
}

function cleanupStaleSlots(
  context: common.Context,
  formId: string,
  oldEntries: Array<WidgetImageEntry>,
  newEntries: Array<WidgetImageEntry>,
): void {
  const oldSlots = collectSlots(formId, oldEntries);
  if (oldSlots.size === 0) {
    return;
  }
  const newSlots = collectSlots(formId, newEntries);
  const baseDir = context.getApplicationContext().cacheDir;
  const cacheDir = `${baseDir}/widget`;

  for (const slot of oldSlots) {
    if (newSlots.has(slot)) {
      continue;
    }
    const filePath = `${cacheDir}/${imageFilenameForSlot(formId, slot)}`;
    const tempPath = `${cacheDir}/${imageTempFilenameForSlot(formId, slot)}`;
    safeUnlink(filePath);
    safeUnlink(tempPath);
  }
}

function collectSlots(formId: string, entries: Array<WidgetImageEntry>): Set<number> {
  const slots = new Set<number>();
  for (const entry of entries) {
    const slot = imageSlotFromName(formId, entry.imgName);
    if (slot !== null) {
      slots.add(slot);
    }
  }
  return slots;
}

function safeUnlink(path: string): void {
  if (!path) {
    return;
  }
  try {
    if (fs.accessSync(path)) {
      fs.unlinkSync(path);
    }
  } catch (_) {
    // ignore delete error
  }
}

function findUnusedSlot(formId: string, entries: Array<WidgetImageEntry>): number | null {
  for (let i = 0; i < MAX_WIDGET_IMAGES; i++) {
    let used = false;
    for (const entry of entries) {
      const slot = imageSlotFromName(formId, entry.imgName);
      if (slot === i) {
        used = true;
        break;
      }
    }
    if (!used) {
      return i;
    }
  }
  return null;
}

async function fetchEntries(
  context: common.Context,
  api: ImmichAPI,
  widgetType: WidgetType,
  formId: string,
  size: number,
  includeCover: boolean,
): Promise<Array<WidgetEntry>> {
  if (widgetType === WidgetType.MEMORIES) {
    return await fetchMemoryEntries(context, api, formId, size, includeCover);
  }
  return await fetchRandomEntries(context, api, formId, size, includeCover);
}

async function fetchRandomEntries(
  context: common.Context,
  api: ImmichAPI,
  formId: string,
  size: number,
  includeCover: boolean,
): Promise<Array<WidgetEntry>> {
  const config = loadWidgetConfig(context, formId);
  const requestSize = Math.max(1, Math.min(size, MAX_WIDGET_IMAGES));
  const filters: SearchFilters = { type: 'IMAGE', size: requestSize };
  let albumId = config.albumId;
  let albumName = config.albumName;
  let subtitle = config.showAlbumName ? albumName : '';
  const shouldAutoSelect = albumId === DEFAULT_ALBUM_ID && !isWidgetAlbumOverride(context, formId);
  let autoSelectedAlbum = false;
  let coverAssetId = '';
  if (shouldAutoSelect) {
    try {
      const albums = await api.fetchAlbums();
      if (albums.length > 0) {
        const first = albums[0];
        albumId = first.id;
        albumName = first.albumName;
        subtitle = config.showAlbumName ? albumName : '';
        const nextConfig: WidgetConfig = {
          albumId,
          albumName,
          showAlbumName: config.showAlbumName,
          refreshMinutes: config.refreshMinutes,
          slideIntervalSeconds: config.slideIntervalSeconds,
        };
        saveWidgetConfig(context, formId, nextConfig);
        markWidgetAlbumOverride(context, formId);
        autoSelectedAlbum = true;
        console.error(`[WidgetUpdate] auto select albumId=${albumId} albumName=${albumName}`);
      }
    } catch (error) {
      console.error(`[WidgetUpdate] auto select album failed error=${error}`);
    }
  }
  const shouldIncludeCover = includeCover && autoSelectedAlbum;
  if (
    shouldIncludeCover &&
    albumId &&
    albumId !== DEFAULT_ALBUM_ID &&
    albumId !== FAVORITES_ALBUM_ID
  ) {
    try {
      const albumInfo = await api.fetchAlbumInfo(albumId);
      coverAssetId = albumInfo?.albumThumbnailAssetId ?? '';
      if (coverAssetId) {
        console.error(`[WidgetUpdate] resolved album cover assetId=${coverAssetId}`);
      }
    } catch (error) {
      console.error(`[WidgetUpdate] fetch album info failed error=${error}`);
    }
  }
  console.error(
    `[WidgetUpdate] fetchRandomEntries formId=${formId} albumId=${albumId} albumName=${albumName} show=${config.showAlbumName}`,
  );

  if (albumId === FAVORITES_ALBUM_ID) {
    filters.isFavorite = true;
  } else if (albumId && albumId !== DEFAULT_ALBUM_ID) {
    filters.albumIds = [albumId];
  }

  let assets = await api.fetchSearchResults(filters);
  console.error(`[WidgetUpdate] fetchRandomEntries results count=${assets?.length ?? 0}`);
  if (!assets || assets.length === 0) {
    if (albumId && albumId !== DEFAULT_ALBUM_ID) {
      assets = await api.fetchSearchResults({ type: 'IMAGE', size: requestSize });
      console.error(`[WidgetUpdate] fallback fetchRandomEntries count=${assets?.length ?? 0}`);
      subtitle = '';
    }
  }
  const safeAssets = Array.isArray(assets) ? assets : [];
  const entries: Array<WidgetEntry> = [];
  if (coverAssetId && safeAssets.some((asset) => asset.id === coverAssetId)) {
    entries.push({
      assetId: coverAssetId,
      subtitle,
      deeplink: assetDeeplink(coverAssetId),
    });
  }
  for (const asset of safeAssets) {
    if (entries.length >= requestSize) {
      break;
    }
    if (coverAssetId && asset.id === coverAssetId) {
      continue;
    }
    entries.push({
      assetId: asset.id,
      subtitle,
      deeplink: assetDeeplink(asset.id),
    });
  }
  if (entries.length === 0) {
    throw new Error('No assets returned');
  }
  return entries;
}

async function fetchMemoryEntries(
  context: common.Context,
  api: ImmichAPI,
  formId: string,
  size: number,
  includeCover: boolean,
): Promise<Array<WidgetEntry>> {
  const today = new Date();
  const memories = await api.fetchMemory(today);
  console.error(`[WidgetUpdate] fetchMemoryEntries count=${memories?.length ?? 0}`);

  const requestSize = Math.max(1, Math.min(size, MAX_WIDGET_IMAGES));
  const safeMemories = Array.isArray(memories) ? memories : [];
  if (safeMemories.length === 0) {
    return await fetchRandomEntries(context, api, formId, size, includeCover);
  }

  const shuffledMemories = safeMemories.slice();
  for (let i = shuffledMemories.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    const tmp = shuffledMemories[i];
    shuffledMemories[i] = shuffledMemories[j];
    shuffledMemories[j] = tmp;
  }

  const entries: Array<WidgetEntry> = [];
  const remainder: Array<WidgetEntry> = [];

  for (const memory of shuffledMemories) {
    const assets = Array.isArray(memory.assets) ? memory.assets : [];
    if (assets.length === 0) {
      continue;
    }
    const yearDiff = today.getFullYear() - memory.data.year;
    const subtitle = `${yearDiff} ${yearDiff === 1 ? 'year' : 'years'} ago`;
    const assetIndex = Math.floor(Math.random() * assets.length);
    const primary = assets[assetIndex];
    if (primary?.id) {
      entries.push({
        assetId: primary.id,
        subtitle,
        deeplink: assetDeeplink(primary.id),
      });
    }
    for (let i = 0; i < assets.length; i++) {
      if (i === assetIndex) {
        continue;
      }
      const asset = assets[i];
      if (asset && asset.id) {
        remainder.push({
          assetId: asset.id,
          subtitle,
          deeplink: assetDeeplink(asset.id),
        });
      }
    }
    if (entries.length >= requestSize) {
      break;
    }
  }

  if (entries.length < requestSize && remainder.length > 0) {
    for (let i = remainder.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      const tmp = remainder[i];
      remainder[i] = remainder[j];
      remainder[j] = tmp;
    }
    for (const entry of remainder) {
      if (entries.length >= requestSize) {
        break;
      }
      entries.push(entry);
    }
  }

  if (entries.length === 0) {
    return await fetchRandomEntries(context, api, formId, size, includeCover);
  }

  return entries.slice(0, requestSize);
}

async function downloadImages(
  context: common.Context,
  api: ImmichAPI,
  entries: Array<WidgetEntry>,
  formId: string,
): Promise<ImageDownloadResult> {
  if (!entries || entries.length === 0) {
    throw new Error('No entries to download');
  }
  const formImages: Record<string, number> = {};
  const files: Array<fs.File> = [];
  const widgetEntries: Array<WidgetImageEntry> = [];
  const targetCount = Math.min(entries.length, MAX_WIDGET_IMAGES);

  for (let i = 0; i < targetCount; i++) {
    const entry = entries[i];
    console.error(`[WidgetUpdate] downloadImage assetId=${entry.assetId} formId=${formId} index=${i}`);
    const buffer = await api.fetchImage(entry.assetId);
    console.error(`[WidgetUpdate] downloaded image bytes=${buffer.byteLength} index=${i}`);
    const filePath = writeBufferToSlot(context, formId, i, buffer);
    const file = fs.openSync(filePath, fs.OpenMode.READ_WRITE);
    formImages[imageNameForSlot(formId, i)] = file.fd;
    files.push(file);
    widgetEntries.push({
      imgName: imageNameForSlot(formId, i),
      text: entry.subtitle ?? '',
      deeplink: entry.deeplink ?? DEFAULT_DEEPLINK,
    });
  }

  return {
    imgName: widgetEntries[0]?.imgName ?? '',
    formImages,
    files,
    entries: widgetEntries,
    nextSlot: targetCount % MAX_WIDGET_IMAGES,
  };
}

function writeBufferToSlot(
  context: common.Context,
  formId: string,
  slot: number,
  buffer: ArrayBuffer,
): string {
  const baseDir = context.getApplicationContext().cacheDir;
  const cacheDir = `${baseDir}/widget`;
  try {
    fs.mkdirSync(cacheDir);
  } catch (_) {
    // ignore if exists
  }

  const filePath = `${cacheDir}/${imageFilenameForSlot(formId, slot)}`;
  const tempPath = `${cacheDir}/${imageTempFilenameForSlot(formId, slot)}`;
  const file = fs.openSync(tempPath, fs.OpenMode.CREATE | fs.OpenMode.READ_WRITE);
  try {
    fs.truncateSync(file.fd, 0);
    fs.writeSync(file.fd, buffer);
    fs.truncateSync(file.fd, buffer.byteLength);
  } finally {
    try {
      fs.closeSync(file);
    } catch (_) {
      // ignore close error
    }
  }

  try {
    fs.renameSync(tempPath, filePath);
  } catch (_) {
    try {
      if (fs.accessSync(filePath)) {
        fs.unlinkSync(filePath);
      }
    } catch (_) {
      // ignore delete error
    }
    fs.renameSync(tempPath, filePath);
  }

  return filePath;
}

function imageNameForSlot(formId: string, index: number): string {
  return `widget_${formId}_${index}`;
}

function imageFilenameForSlot(formId: string, index: number): string {
  return `widget_image_${formId}_${index}.jpg`;
}

function imageTempFilenameForSlot(formId: string, index: number): string {
  return `widget_image_${formId}_${index}.tmp`;
}
