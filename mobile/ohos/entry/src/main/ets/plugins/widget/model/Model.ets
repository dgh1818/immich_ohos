import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

export const WIDGET_PREF_NAME = 'Immich::Widget';
export const WIDGET_SERVER_URL_KEY = 'widget_server_url';
export const WIDGET_AUTH_TOKEN_KEY = 'widget_auth_token';
export const WIDGET_CUSTOM_HEADERS_KEY = 'widget_custom_headers';
export const WIDGET_FORM_MAP_KEY = 'widget_form_map';
export const WIDGET_FORM_NAME_MAP_KEY = 'widget_form_name_map';
export const WIDGET_CONFIG_MAP_KEY = 'widget_config_map';
const WIDGET_ALBUM_OVERRIDE_PREFIX = 'widget_album_override_';

export const FORM_NAME_RANDOM = 'ImmichRandom';
export const FORM_NAME_MEMORIES = 'ImmichMemories';

export const DEFAULT_ALBUM_ID = 'NONE';
export const FAVORITES_ALBUM_ID = 'FAVORITES';
export const DEFAULT_ALBUM_NAME = 'None';
export const DEFAULT_REFRESH_MINUTES = 30;
export const DEFAULT_SLIDE_INTERVAL_SECONDS = 5;


export enum WidgetType {
  RANDOM = 'RANDOM',
  MEMORIES = 'MEMORIES',
}

export enum WidgetState {
  LOADING = 'LOADING',
  SUCCESS = 'SUCCESS',
  LOG_IN = 'LOG_IN',
  ERROR = 'ERROR',
}

export enum WidgetConfigState {
  LOADING = 'LOADING',
  SUCCESS = 'SUCCESS',
  LOG_IN = 'LOG_IN',
  NO_CONNECTION = 'NO_CONNECTION',
}

export interface Asset {
  id: string;
  type?: string;
}

export interface SearchFilters {
  type?: string;
  size?: number;
  albumIds?: Array<string>;
  isFavorite?: boolean;
}

export interface MemoryData {
  year: number;
}

export interface MemoryResult {
  id: string;
  assets: Array<Asset>;
  type?: string;
  data: MemoryData;
}

export interface Album {
  id: string;
  albumName: string;
}

export interface AlbumInfo {
  albumThumbnailAssetId?: string;
}

export interface WidgetEntry {
  assetId: string;
  subtitle: string;
  deeplink: string;
}

export interface WidgetImageEntry {
  imgName: string;
  text: string;
  deeplink: string;
}

export interface ServerConfig {
  serverEndpoint: string;
  sessionKey: string;
  customHeaders: Record<string, string>;
}

export interface WidgetFormData {
  text: string;
  loaded: boolean;
  imgName: string;
  formImages: Record<string, number>;
  deeplink: string;
  entriesJson: string;
  activeIndex: number;
  slideIntervalSeconds: number;
  state: WidgetState;
}


export interface WidgetConfig {
  albumId: string;
  albumName: string;
  showAlbumName: boolean;
  refreshMinutes: number;
  slideIntervalSeconds: number;
}

export type WidgetFormMap = Record<string, WidgetType>;
export type WidgetFormNameMap = Record<string, string>;
export type WidgetConfigMap = Record<string, WidgetConfig>;

export function imageFilename(formId: string): string {
  return `widget_image_${formId}.jpg`;
}

export function assetDeeplink(assetId: string): string {
  return `immich://asset?id=${assetId}`;
}

const OPTIONS: preferences.Options = { name: WIDGET_PREF_NAME };

export function saveWidgetData(context: common.Context, key: string, value: string): void {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  pref.putSync(key, value);
  pref.flushSync();
}

export function loadWidgetData(context: common.Context, key: string, defaultValue: string): string {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  return pref.getSync(key, defaultValue) as string;
}

export function markWidgetAlbumOverride(context: common.Context, formId: string): void {
  if (!formId) {
    return;
  }
  saveWidgetData(context, `${WIDGET_ALBUM_OVERRIDE_PREFIX}${formId}`, '1');
}

export function isWidgetAlbumOverride(context: common.Context, formId: string): boolean {
  if (!formId) {
    return false;
  }
  const flag = loadWidgetData(context, `${WIDGET_ALBUM_OVERRIDE_PREFIX}${formId}`, '0');
  return flag === '1';
}

const WIDGET_ENTRIES_KEY_PREFIX = 'widget_entries_';
const WIDGET_INDEX_KEY_PREFIX = 'widget_index_';
const WIDGET_SLOT_KEY_PREFIX = 'widget_slot_';

export function saveWidgetEntries(context: common.Context, formId: string, entriesJson: string): void {
  if (!formId) {
    return;
  }
  saveWidgetData(context, `${WIDGET_ENTRIES_KEY_PREFIX}${formId}`, entriesJson);
}

export function loadWidgetEntries(context: common.Context, formId: string): string {
  if (!formId) {
    return '[]';
  }
  return loadWidgetData(context, `${WIDGET_ENTRIES_KEY_PREFIX}${formId}`, '[]');
}

export function saveWidgetIndex(context: common.Context, formId: string, index: number): void {
  if (!formId) {
    return;
  }
  saveWidgetData(context, `${WIDGET_INDEX_KEY_PREFIX}${formId}`, `${index}`);
}

export function loadWidgetIndex(context: common.Context, formId: string): number {
  if (!formId) {
    return 0;
  }
  const raw = loadWidgetData(context, `${WIDGET_INDEX_KEY_PREFIX}${formId}`, '0');
  const parsed = parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return parsed;
}

export function saveWidgetSlot(context: common.Context, formId: string, slot: number): void {
  if (!formId) {
    return;
  }
  saveWidgetData(context, `${WIDGET_SLOT_KEY_PREFIX}${formId}`, `${slot}`);
}

export function loadWidgetSlot(context: common.Context, formId: string): number {
  if (!formId) {
    return 0;
  }
  const raw = loadWidgetData(context, `${WIDGET_SLOT_KEY_PREFIX}${formId}`, '0');
  const parsed = parseInt(raw, 10);
  if (!Number.isFinite(parsed)) {
    return 0;
  }
  return parsed;
}

export function loadServerConfig(context: common.Context): ServerConfig | null {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  const serverEndpoint = pref.getSync(WIDGET_SERVER_URL_KEY, '') as string;
  const sessionKey = pref.getSync(WIDGET_AUTH_TOKEN_KEY, '') as string;
  const headersJson = pref.getSync(WIDGET_CUSTOM_HEADERS_KEY, '') as string;

  if (!serverEndpoint || !sessionKey) {
    return null;
  }

  let customHeaders: Record<string, string> = {};
  if (headersJson) {
    try {
      const parsed = JSON.parse(headersJson) as Record<string, string>;
      if (parsed !=undefined) {
        customHeaders = parsed;
      }
    } catch (_) {
      customHeaders = {};
    }
  }

  const config: ServerConfig = {
    serverEndpoint,
    sessionKey,
    customHeaders,
  };
  return config;
}

export function loadFormMap(context: common.Context): WidgetFormMap {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  const raw = pref.getSync(WIDGET_FORM_MAP_KEY, '') as string;
  if (!raw) {
    const emptyMap: WidgetFormMap = {};
    return emptyMap;
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, WidgetType>;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      return parsed;
    }
  } catch (_) {
    // ignore invalid JSON
  }
  const fallback: WidgetFormMap = {};
  return fallback;
}

export function saveFormMap(context: common.Context, formMap: WidgetFormMap): void {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  pref.putSync(WIDGET_FORM_MAP_KEY, JSON.stringify(formMap));
  pref.flushSync();
}

export function loadFormNameMap(context: common.Context): WidgetFormNameMap {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  const raw = pref.getSync(WIDGET_FORM_NAME_MAP_KEY, '') as string;
  if (!raw) {
    const emptyMap: WidgetFormNameMap = {};
    return emptyMap;
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, string>;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      const sanitized: WidgetFormNameMap = {};
      for (const key of Object.keys(parsed)) {
        const value = parsed[key];
        if (typeof value === 'string') {
          sanitized[key] = value;
        }
      }
      return sanitized;
    }
  } catch (_) {
    // ignore invalid JSON
  }
  const fallback: WidgetFormNameMap = {};
  return fallback;
}

export function saveFormNameMap(context: common.Context, formMap: WidgetFormNameMap): void {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  pref.putSync(WIDGET_FORM_NAME_MAP_KEY, JSON.stringify(formMap));
  pref.flushSync();
}

export function loadWidgetConfigMap(context: common.Context): WidgetConfigMap {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  const raw = pref.getSync(WIDGET_CONFIG_MAP_KEY, '') as string;
  console.error(`[WidgetModel] loadWidgetConfigMap rawLen=${raw.length}`);
  if (!raw) {
    const emptyMap: WidgetConfigMap = {};
    return emptyMap;
  }
  try {
    const parsed = JSON.parse(raw) as Record<string, WidgetConfig>;
    if (parsed && typeof parsed === 'object' && !Array.isArray(parsed)) {
      console.error(`[WidgetModel] loadWidgetConfigMap parsed keys=${Object.keys(parsed).join(',')}`);
      return parsed;
    }
  } catch (_) {
    // ignore invalid JSON
  }
  const fallback: WidgetConfigMap = {};
  console.error('[WidgetModel] loadWidgetConfigMap fallback empty');
  return fallback;
}

export function saveWidgetConfigMap(context: common.Context, configMap: WidgetConfigMap): void {
  const pref = preferences.getPreferencesSync(context, OPTIONS);
  console.error(`[WidgetModel] saveWidgetConfigMap keys=${Object.keys(configMap).join(',')}`);
  pref.putSync(WIDGET_CONFIG_MAP_KEY, JSON.stringify(configMap));
  pref.flushSync();
}

export function loadWidgetConfig(context: common.Context, formId: string): WidgetConfig {
  console.error(`[WidgetModel] loadWidgetConfig formId=${formId}`);
  const configMap = loadWidgetConfigMap(context);
  const config = configMap[formId];
  if (config) {
    const refreshMinutes = DEFAULT_REFRESH_MINUTES;
    const slideIntervalSeconds =
      typeof config.slideIntervalSeconds === 'number' && config.slideIntervalSeconds > 0
        ? config.slideIntervalSeconds
        : DEFAULT_SLIDE_INTERVAL_SECONDS;
    const normalized: WidgetConfig = {
      albumId: config.albumId ?? DEFAULT_ALBUM_ID,
      albumName: config.albumName ?? DEFAULT_ALBUM_NAME,
      showAlbumName: config.showAlbumName ?? false,
      refreshMinutes,
      slideIntervalSeconds,
    };
    console.error(
      `[WidgetModel] loadWidgetConfig hit albumId=${normalized.albumId} albumName=${normalized.albumName} show=${normalized.showAlbumName} refresh=${normalized.refreshMinutes} slide=${normalized.slideIntervalSeconds}`
    );
    return normalized;
  }
  const fallback: WidgetConfig = {
    albumId: DEFAULT_ALBUM_ID,
    albumName: DEFAULT_ALBUM_NAME,
    showAlbumName: false,
    refreshMinutes: DEFAULT_REFRESH_MINUTES,
    slideIntervalSeconds: DEFAULT_SLIDE_INTERVAL_SECONDS,
  };
  console.error('[WidgetModel] loadWidgetConfig fallback');
  return fallback;
}

export function saveWidgetConfig(context: common.Context, formId: string, config: WidgetConfig): void {
  const refreshMinutes = DEFAULT_REFRESH_MINUTES;
  const slideIntervalSeconds =
    typeof config.slideIntervalSeconds === 'number' && config.slideIntervalSeconds > 0
      ? config.slideIntervalSeconds
      : DEFAULT_SLIDE_INTERVAL_SECONDS;
  const normalized: WidgetConfig = {
    albumId: config.albumId,
    albumName: config.albumName,
    showAlbumName: config.showAlbumName,
    refreshMinutes,
    slideIntervalSeconds,
  };
  console.error(
    `[WidgetModel] saveWidgetConfig formId=${formId} albumId=${normalized.albumId} albumName=${normalized.albumName} show=${normalized.showAlbumName} refresh=${normalized.refreshMinutes} slide=${normalized.slideIntervalSeconds}`
  );
  const configMap = loadWidgetConfigMap(context);
  configMap[formId] = normalized;
  saveWidgetConfigMap(context, configMap);
}
