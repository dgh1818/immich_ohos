import { http } from '@kit.NetworkKit';
import { ServerConfig, SearchFilters, MemoryResult, Asset, Album, AlbumInfo } from './model/Model';

export class ImmichAPI {
  private readonly config: ServerConfig;

  constructor(config: ServerConfig) {
    this.config = config;
  }

  async fetchSearchResults(filters: SearchFilters): Promise<Array<Asset>> {
    const url = this.buildRequestUrl('/search/random');
    const body = JSON.stringify(filters);
    return (await this.requestJson(url, http.RequestMethod.POST, body)) as Array<Asset>;
  }

  async fetchMemory(date: Date): Promise<Array<MemoryResult>> {
    const isoDate = this.formatDate(date);
    const url = this.buildRequestUrl('/memories', { 'for': isoDate });
    return (await this.requestJson(url, http.RequestMethod.GET)) as Array<MemoryResult>;
  }

  async fetchAlbums(): Promise<Array<Album>> {
    const url = this.buildRequestUrl('/albums');
    return (await this.requestJson(url, http.RequestMethod.GET)) as Array<Album>;
  }

  async fetchAlbumInfo(albumId: string): Promise<AlbumInfo | null> {
    if (!albumId) {
      return null;
    }
    const url = this.buildRequestUrl(`/albums/${albumId}`, { 'withoutAssets': 'true' });
    return (await this.requestJson(url, http.RequestMethod.GET)) as AlbumInfo;
  }

  async fetchImage(assetId: string): Promise<ArrayBuffer> {
    const url = this.buildRequestUrl(`/assets/${assetId}/thumbnail`, { 'size': 'preview', 'edited': 'true' });
    return await this.requestBytes(url);
  }

  private buildRequestUrl(endpoint: string, params: Record<string, string> = {}): string {
    let url = `${this.config.serverEndpoint}${endpoint}?sessionKey=${encodeURIComponent(this.config.sessionKey)}`;

    const keys = Object.keys(params); // params: Record<string, string>
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = params[key];
      url += `&${encodeURIComponent(key)}=${encodeURIComponent(value)}`;
    }

    return url;
  }

  private buildHeaders(): Record<string, string> {
    const headers: Record<string, string> = {};
    const customHeaders = this.config.customHeaders;
    if (customHeaders) {
      const keys = Object.keys(customHeaders);
      for (let i = 0; i < keys.length; i++) {
        const key = keys[i];
        headers[key] = customHeaders[key];
      }
    }
    return headers;
  }

  private async requestJson(url: string, method: http.RequestMethod, body?: string): Promise<ESObject> {
    const request = http.createHttp();
    const headers = this.buildHeaders();
    headers['Content-Type'] = 'application/json';

    const options: http.HttpRequestOptions = {
      method,
      header: headers,
      expectDataType: http.HttpDataType.STRING,
    };
    if (body !== undefined) {
      options.extraData = body;
    }

    try {
      const response = await request.request(url, options);
      if (response.responseCode < 200 || response.responseCode > 299) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      const text = response.result as string;
      return JSON.parse(text);
    } finally {
      request.destroy();
    }
  }

  private async requestBytes(url: string): Promise<ArrayBuffer> {
    const request = http.createHttp();
    const headers = this.buildHeaders();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headers,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
    };

    try {
      const response = await request.request(url, options);
      if (response.responseCode < 200 || response.responseCode > 299) {
        throw new Error(`HTTP ${response.responseCode}`);
      }
      return response.result as ArrayBuffer;
    } finally {
      request.destroy();
    }
  }

  private formatDate(date: Date): string {
    const year = date.getFullYear();
    const month = `${date.getMonth() + 1}`.padStart(2, '0');
    const day = `${date.getDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }
}
