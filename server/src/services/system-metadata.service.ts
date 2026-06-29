import { Injectable } from '@nestjs/common';
import {
  AdminOnboardingResponseDto,
  AdminOnboardingUpdateDto,
  ReverseGeocodingStateResponseDto,
  VersionCheckStateResponseDto,
} from 'src/dtos/system-metadata.dto';
import { JobName, SystemMetadataKey } from 'src/enum';
import { BaseService } from 'src/services/base.service';
import { OhosLivePhotoRescanState } from 'src/types';

const emptyOhosLivePhotoRescanState = (): OhosLivePhotoRescanState => ({
  status: 'completed',
  mode: 'all',
  scanned: 0,
  detected: 0,
  matched: 0,
  alreadyMatched: 0,
  missing: 0,
  skipped: 0,
  failed: 0,
  failures: [],
});

@Injectable()
export class SystemMetadataService extends BaseService {
  async getAdminOnboarding(): Promise<AdminOnboardingResponseDto> {
    const value = await this.systemMetadataRepository.get(SystemMetadataKey.AdminOnboarding);
    return { isOnboarded: false, ...value };
  }

  async updateAdminOnboarding(dto: AdminOnboardingUpdateDto): Promise<void> {
    await this.systemMetadataRepository.set(SystemMetadataKey.AdminOnboarding, {
      isOnboarded: dto.isOnboarded,
    });
  }

  async getReverseGeocodingState(): Promise<ReverseGeocodingStateResponseDto> {
    const value = await this.systemMetadataRepository.get(SystemMetadataKey.ReverseGeocodingState);
    return { lastUpdate: null, lastImportFileName: null, ...value };
  }

  async getVersionCheckState(): Promise<VersionCheckStateResponseDto> {
    const value = await this.systemMetadataRepository.get(SystemMetadataKey.VersionCheckState);
    return { checkedAt: null, releaseVersion: null, ...value };
  }

  async getOhosLivePhotoRescanState(): Promise<OhosLivePhotoRescanState> {
    const state = {
      ...emptyOhosLivePhotoRescanState(),
      ...(await this.systemMetadataRepository.get(SystemMetadataKey.OhosLivePhotoRescan)),
    };
    state.failed = state.failures.length;
    return state;
  }

  async queueOhosLivePhotoRescan(retryFailed = false): Promise<OhosLivePhotoRescanState> {
    const current = await this.getOhosLivePhotoRescanState();
    const now = new Date().toISOString();
    const state: OhosLivePhotoRescanState = retryFailed
      ? {
          ...emptyOhosLivePhotoRescanState(),
          status: 'queued',
          mode: 'failed',
          queuedAt: now,
          total: current.failures.length,
          failures: current.failures,
        }
      : {
          ...emptyOhosLivePhotoRescanState(),
          status: 'queued',
          mode: 'all',
          queuedAt: now,
          total: await this.assetJobRepository.countForOhosLivePhotoRescan(),
        };

    await this.systemMetadataRepository.set(SystemMetadataKey.OhosLivePhotoRescan, state);
    await this.jobRepository.queue({ name: JobName.AssetOhosLivePhotoRescan, data: { retryFailed } });
    return state;
  }
}
