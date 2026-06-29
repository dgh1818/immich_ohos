<script lang="ts">
  import { handleError } from '$lib/utils/handle-error';
  import { getBaseUrl } from '@immich/sdk';
  import { Icon, toastManager } from '@immich/ui';
  import { mdiRefresh, mdiReplay } from '@mdi/js';
  import { onMount } from 'svelte';

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

<section class="rounded-2xl bg-gray-100 p-5 sm:p-7 md:p-9 dark:bg-immich-dark-gray">
  <div class="flex flex-col gap-5">
    <div class="flex flex-col justify-between gap-4 sm:flex-row sm:items-start">
      <div>
        <h2 class="text-xl font-semibold text-primary">OHOS Live Photo rescan</h2>
        <p class="mt-1 text-sm text-gray-600 dark:text-gray-300">
          Rematch OHOS Live Photo image/video companion files and keep retryable failures.
        </p>
      </div>

      <div class="flex flex-wrap gap-2">
        <button
          type="button"
          class="flex items-center gap-2 rounded-lg bg-immich-primary px-3 py-2 text-sm text-white disabled:cursor-not-allowed disabled:opacity-60 dark:bg-immich-dark-primary dark:text-black"
          disabled={submitting || isActive}
          onclick={() => queueRescan(false)}
        >
          <Icon icon={mdiRefresh} size="18" />
          <span>Rescan</span>
        </button>
        <button
          type="button"
          class="flex items-center gap-2 rounded-lg bg-gray-300 px-3 py-2 text-sm text-gray-700 disabled:cursor-not-allowed disabled:opacity-60 dark:bg-gray-700 dark:text-gray-200"
          disabled={submitting || isActive || failures.length === 0}
          onclick={() => queueRescan(true)}
        >
          <Icon icon={mdiReplay} size="18" />
          <span>Retry failed</span>
        </button>
      </div>
    </div>

    {#if rescanState}
      <div class="h-2 overflow-hidden rounded-full bg-gray-300 dark:bg-gray-700">
        <div class="h-full bg-immich-primary dark:bg-immich-dark-primary" style={`width: ${progress}%`}></div>
      </div>

      <div class="grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
        <div>
          <p class="text-gray-500 dark:text-gray-400">Status</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.status}</p>
        </div>
        <div>
          <p class="text-gray-500 dark:text-gray-400">Scanned</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">
            {rescanState.scanned}{rescanState.total ? ` / ${rescanState.total}` : ''}
          </p>
        </div>
        <div>
          <p class="text-gray-500 dark:text-gray-400">Matched</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">
            {rescanState.matched} new, {rescanState.alreadyMatched} existing
          </p>
        </div>
        <div>
          <p class="text-gray-500 dark:text-gray-400">Failures</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">{failures.length}</p>
        </div>
      </div>

      <div class="grid grid-cols-2 gap-3 text-sm md:grid-cols-4">
        <div>
          <p class="text-gray-500 dark:text-gray-400">Detected</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.detected}</p>
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
          <p class="text-gray-500 dark:text-gray-400">Mode</p>
          <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.mode}</p>
        </div>
      </div>

      {#if rescanState.current}
        <div class="rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
          <p class="font-medium">{rescanState.current.stage}: {rescanState.current.assetId}</p>
          <p class="mt-1 break-all">{rescanState.current.originalPath}</p>
        </div>
      {/if}

      {#if failures.length > 0}
        <div class="rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
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
</section>
