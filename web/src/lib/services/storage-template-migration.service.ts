import { getBaseUrl } from '@immich/sdk';

export type StorageTemplateMigrationFailure = {
  assetId: string;
  retryAssetId?: string;
  originalPath: string;
  targetPath?: string;
  stage: string;
  reason: string;
  failedAt: string;
  attempts: number;
  timedOut?: boolean;
};

export type StorageTemplateMigrationState = {
  queuedAt: string;
  startedAt?: string;
  completedAt?: string;
  scanned?: number;
  failed?: number;
  current?: {
    assetId: string;
    originalPath: string;
    targetPath?: string;
    stage: string;
    startedAt: string;
  };
  failures?: StorageTemplateMigrationFailure[];
  afterId?: string;
};

const request = async (path: string, init?: RequestInit): Promise<StorageTemplateMigrationState> => {
  const response = await fetch(`${getBaseUrl()}${path}`, init);
  if (!response.ok) {
    throw new Error(await response.text());
  }

  return response.json();
};

export const getStorageTemplateMigrationState = () => request('/system-config/storage-template-migration');

export const retryStorageTemplateMigrationFailures = () =>
  request('/system-config/storage-template-migration/retry-failed', { method: 'POST' });

export const clearStorageTemplateMigrationFailures = () =>
  request('/system-config/storage-template-migration/failures', { method: 'DELETE' });
