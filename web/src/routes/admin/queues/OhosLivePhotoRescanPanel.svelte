<script lang="ts">
  import { handleError } from '$lib/utils/handle-error';
  import { getBaseUrl } from '@immich/sdk';
  import { Icon, toastManager } from '@immich/ui';
  import { mdiImageRefreshOutline, mdiReplay } from '@mdi/js';
  import { onMount } from 'svelte';
  import QueueCardBadge from './QueueCardBadge.svelte';
  import QueueCardButton from './QueueCardButton.svelte';

  type OhosLivePhotoRescanState = {
    status: 'queued' | 'running' | 'completed' | 'failed';
    mode: 'all' | 'failed';
    queuedAt?: string;
    startedAt?: string;
    completedAt?: string;
    total?: number;
    scanned: number;
    detected: number;
    matched: number;
    alreadyMatched: number;
    missing: number;
    skipped: number;
    failed: number;
    current?: {
      assetId: string;
      type: string;
      originalPath: string;
      stage: string;
      startedAt: string;
    };
    failures: {
      assetId: string;
      originalPath: string;
      originalFileName?: string;
      stage: string;
      reason: string;
      failedAt: string;
      attempts: number;
    }[];
  };

  let rescanState = $state<OhosLivePhotoRescanState>();
  let loading = $state(false);
  let submitting = $state(false);
  let pollTimer: ReturnType<typeof setTimeout> | undefined;

  const isActive = $derived(rescanState?.status === 'queued' || rescanState?.status === 'running');
  const progress = $derived(
    rescanState?.total ? Math.min(100, Math.round((rescanState.scanned / rescanState.total) * 100)) : 0,
  );
  const failures = $derived(rescanState?.failures ?? []);

  const request = async (path: string, init?: RequestInit): Promise<OhosLivePhotoRescanState> => {
    const response = await fetch(`${getBaseUrl()}${path}`, init);
    if (!response.ok) {
      throw new Error(await response.text());
    }

    return response.json();
  };

  const schedulePoll = () => {
    clearTimeout(pollTimer);
    if (rescanState?.status === 'queued' || rescanState?.status === 'running') {
      pollTimer = setTimeout(() => void loadState(), 3000);
    }
  };

  const loadState = async () => {
    loading = true;
    try {
      rescanState = await request('/system-metadata/ohos-live-photo-rescan');
      schedulePoll();
    } catch (error) {
      handleError(error, 'Failed to load OHOS Live Photo rescan state');
    } finally {
      loading = false;
    }
  };

  const queueRescan = async (retryFailed = false) => {
    submitting = true;
    try {
      rescanState = await request(
        retryFailed
          ? '/system-metadata/ohos-live-photo-rescan/retry-failed'
          : '/system-metadata/ohos-live-photo-rescan',
        { method: 'POST' },
      );
      toastManager.primary(retryFailed ? 'Queued failed OHOS Live Photo retries' : 'Queued OHOS Live Photo rescan');
      schedulePoll();
    } catch (error) {
      handleError(
        error,
        retryFailed ? 'Failed to retry OHOS Live Photo failures' : 'Failed to queue OHOS Live Photo rescan',
      );
    } finally {
      submitting = false;
    }
  };

  onMount(() => {
    void loadState();
    return () => clearTimeout(pollTimer);
  });
</script>

<div class="sm:rounded-9 flex flex-col overflow-hidden rounded-2xl bg-gray-100 sm:flex-row dark:bg-immich-dark-gray">
  <div class="flex w-full flex-col">
    {#if isActive}
      <QueueCardBadge color="success">Active</QueueCardBadge>
    {:else if rescanState?.status === 'failed'}
      <QueueCardBadge color="warning">Failed</QueueCardBadge>
    {/if}

    <div class="flex flex-col gap-2 p-5 sm:p-7 md:p-9">
      <div class="flex items-center gap-2 text-xl font-semibold text-primary">
        <Icon icon={mdiImageRefreshOutline} size="1.25em" class="hidden shrink-0 sm:block" />
        <span>OHOS Live Photo rescan</span>
      </div>

      <div class="text-sm whitespace-pre-line dark:text-white">
        Rematch OHOS Live Photo image/video companion files. AI enhanced XtStyle files are checked as candidates; when
        no companion video exists, they are not counted as missing pairs.
      </div>

      {#if rescanState}
        <div class="mt-2 h-2 w-full max-w-md overflow-hidden rounded-full bg-gray-300 dark:bg-gray-700">
          <div class="h-full bg-immich-primary dark:bg-immich-dark-primary" style={`width: ${progress}%`}></div>
        </div>

        <div class="mt-2 flex w-full max-w-md flex-col sm:flex-row">
          <div
            class="flex w-full place-items-center justify-between rounded-t-lg bg-immich-primary px-6 py-2 text-white sm:rounded-s-lg sm:rounded-e-none sm:py-4 dark:bg-immich-dark-primary dark:text-immich-dark-gray"
          >
            <p>Scanned</p>
            <p class="text-2xl">
              {rescanState.scanned}{rescanState.total ? ` / ${rescanState.total}` : ''}
            </p>
          </div>

          <div
            class="flex w-full flex-row-reverse place-items-center justify-between rounded-b-lg bg-gray-200 px-6 py-2 text-immich-dark-bg sm:rounded-s-none sm:rounded-e-lg sm:py-4 dark:bg-gray-700 dark:text-immich-gray"
          >
            <p class="text-2xl">
              {rescanState.detected}
            </p>
            <p>Candidates</p>
          </div>
        </div>

        <div class="mt-2 grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
          <div>
            <p class="text-gray-500 dark:text-gray-400">Matched</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">
              {rescanState.matched} new, {rescanState.alreadyMatched} existing
            </p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">Missing pair</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.missing}</p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">Skipped</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.skipped}</p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">Failures</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{failures.length}</p>
          </div>
        </div>

        {#if rescanState.current}
          <div class="mt-2 rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
            <p class="font-medium">{rescanState.current.stage}: {rescanState.current.assetId}</p>
            <p class="mt-1 break-all">{rescanState.current.originalPath}</p>
          </div>
        {/if}

        {#if failures.length > 0}
          <div class="mt-2 rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
            <p class="mb-2 font-medium">Recent failures</p>
            <div class="flex flex-col gap-2">
              {#each failures.slice(0, 5) as failure (failure.assetId)}
                <div>
                  <p class="break-all">{failure.originalPath}</p>
                  <p class="text-gray-500 dark:text-gray-400">
                    {failure.stage}: {failure.reason} (attempts: {failure.attempts})
                  </p>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {:else if loading}
        <p class="text-sm text-gray-600 dark:text-gray-300">Loading...</p>
      {/if}
    </div>
  </div>

  <div class="flex w-full flex-row overflow-hidden sm:w-32 sm:flex-col">
    {#if isActive}
      <QueueCardButton disabled={true} color="light-gray">
        <Icon icon={mdiImageRefreshOutline} size="36" />
        <span>Running</span>
      </QueueCardButton>
    {:else}
      <QueueCardButton
        color={failures.length > 0 ? 'dark-gray' : 'light-gray'}
        disabled={submitting}
        onClick={() => queueRescan(false)}
      >
        <Icon icon={mdiImageRefreshOutline} size={failures.length > 0 ? '24' : '48'} />
        <span>Rescan</span>
      </QueueCardButton>
      {#if failures.length > 0}
        <QueueCardButton color="light-gray" disabled={submitting} onClick={() => queueRescan(true)}>
          <Icon icon={mdiReplay} size="24" />
          <span>Retry</span>
        </QueueCardButton>
      {/if}
    {/if}
  </div>
</div>
