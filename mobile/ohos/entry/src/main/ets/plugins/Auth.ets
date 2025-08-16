import { collections } from '@kit.ArkTS';

interface Auth_interface {
  accessToken?: string;
  accessHeaders?: collections.Map<string, string>;
  accessQueryParams?: collections.Map<string, string>;
  accessTokenExpiryTime?: number;
  refreshToken?: string;
  refreshHeaders?: collections.Map<string, string>;
  refreshQueryParams?: collections.Map<string, string>;
  refreshUrl?: string;
  onAuthRawHandle?: number;
}

@Sendable
export class Auth {
  accessToken?: string;
  accessHeaders: collections.Map<string, string> = new collections.Map();
  accessQueryParams: collections.Map<string, string> = new collections.Map();
  accessTokenExpiryTime?: number;
  refreshToken?: string;
  refreshHeaders: collections.Map<string, string> = new collections.Map();
  refreshQueryParams: collections.Map<string, string> = new collections.Map();
  refreshUrl?: string;
  onAuthRawHandle?: number;

  // 构造函数允许对象字面量初始化
  constructor(init?: Auth_interface) {
    if (init) {
      if (init.accessToken) this.accessToken = init.accessToken;
      if (init.accessHeaders) this.accessHeaders = init.accessHeaders;
      if (init.accessQueryParams) this.accessQueryParams = init.accessQueryParams;
      if (init.accessTokenExpiryTime) this.accessTokenExpiryTime = init.accessTokenExpiryTime;
      if (init.refreshToken) this.refreshToken = init.refreshToken;
      if (init.refreshHeaders) this.refreshHeaders = init.refreshHeaders;
      if (init.refreshQueryParams) this.refreshQueryParams = init.refreshQueryParams;
      if (init.refreshUrl) this.refreshUrl = init.refreshUrl;
      if (init.onAuthRawHandle) this.onAuthRawHandle = init.onAuthRawHandle;
    }
  }

  getExpandedAccessHeaders(): collections.Map<string, string> {
    return this.expandMap(this.accessHeaders);
  }

  getExpandedAccessQueryParams(): collections.Map<string, string> {
    return this.expandMap(this.accessQueryParams);
  }

  addOrUpdateQueryParams(url: string, queryParams: collections.Map<string, string> = new collections.Map()): string {
    if (queryParams.size == 0) {
      return url;
    }

    // 先分离 base URL 和已有查询参数
    let base = url;
    let existingQuery = "";
    const qIndex = url.indexOf("?");
    if (qIndex !== -1) {
      base = url.substring(0, qIndex);
      existingQuery = url.substring(qIndex + 1);
    }

    // 解析已有查询参数到 Map
    const queryMap = new collections.Map<string, string>();
    if (existingQuery.length > 0) {
      const pairs = existingQuery.split("&");
      for (let i = 0; i < pairs.length; i++) {
        const eqIndex = pairs[i].indexOf("=");
        if (eqIndex !== -1) {
          const k = pairs[i].substring(0, eqIndex);
          const v = pairs[i].substring(eqIndex + 1);
          queryMap.set(k, v);
        }
      }
    }

    // 添加/覆盖 queryParams
    const iter = queryParams.keys();
    let nextKey = iter.next();
    while (!nextKey.done) {
      const key = nextKey.value;
      const value = queryParams.get(key);
      if (value !== undefined) {
        queryMap.set(key, value);
      }
      nextKey = iter.next();
    }

    // 拼接回字符串
    let queryStr = "";
    const queryIter = queryMap.keys();
    let qKey = queryIter.next();
    let first = true;
    while (!qKey.done) {
      const k = qKey.value;
      const v = queryMap.get(k);
      if (v !== undefined) {
        if (!first) {
          queryStr += "&";
        }
        queryStr += k + "=" + v;
        first = false;
      }
      qKey = queryIter.next();
    }

    return base + (queryStr.length > 0 ? "?" + queryStr : "");
  }

  isTokenExpired(bufferTime: number = 10000): boolean {
    if (!this.accessTokenExpiryTime) return false;
    return Date.now() + bufferTime > this.accessTokenExpiryTime;
  }

  private expandMap(mapToExpand: collections.Map<string, string>): collections.Map<string, string> {
    const newMap = new collections.Map<string, string>();
    const keysIter = mapToExpand.keys(); // IterableIterator<string>
    let nextKey = keysIter.next();

    while (!nextKey.done) {
      const key = nextKey.value;
      const value = mapToExpand.get(key);
      if (value !== undefined) {
        let newValue = value;
        if (this.accessToken) newValue = newValue.replace("{accessToken}", this.accessToken);
        if (this.refreshToken) newValue = newValue.replace("{refreshToken}", this.refreshToken);
        newMap.set(key, newValue);
      }
      nextKey = keysIter.next();
    }

    return newMap;
  }

  hasOnAuthCallback(): boolean {
    return this.onAuthRawHandle != null;
  }
}

