<script lang="ts">
  import { handleError } from '$lib/utils/handle-error';
  import { getBaseUrl } from '@immich/sdk';
  import { Icon, toastManager } from '@immich/ui';
  import { mdiImageRefreshOutline, mdiPause, mdiPlay, mdiReplay, mdiStop } from '@mdi/js';
  import { onMount } from 'svelte';
  import QueueCardBadge from './QueueCardBadge.svelte';
  import QueueCardButton from './QueueCardButton.svelte';

  type OhosLivePhotoRescanState = {
    status: 'queued' | 'running' | 'paused' | 'canceled' | 'completed' | 'failed';
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
  const isPaused = $derived(rescanState?.status === 'paused');
  const progress = $derived(
    rescanState?.total ? Math.min(100, Math.round((rescanState.scanned / rescanState.total) * 100)) : 0,
  );
  const failures = $derived(rescanState?.failures ?? []);
  const stageLabel = (stage: string) =>
    ({
      detecting: '检测',
      matching: '匹配',
    })[stage] ?? stage;

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
      handleError(error, '加载 OHOS 动态照片重新匹配状态失败');
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
      toastManager.primary(retryFailed ? '已加入缺失项重试队列' : '已加入全部重新匹配队列');
      schedulePoll();
    } catch (error) {
      handleError(error, retryFailed ? '加入缺失项重试队列失败' : '加入全部重新匹配队列失败');
    } finally {
      submitting = false;
    }
  };

  const updateRescan = async (action: 'resume' | 'pause' | 'cancel') => {
    submitting = true;
    try {
      rescanState = await request(`/system-metadata/ohos-live-photo-rescan/${action}`, { method: 'POST' });
      toastManager.primary(
        {
          resume: '已继续 OHOS 动态照片重新匹配',
          pause: '已暂停 OHOS 动态照片重新匹配',
          cancel: '已终止 OHOS 动态照片重新匹配',
        }[action],
      );
      schedulePoll();
    } catch (error) {
      handleError(
        error,
        {
          resume: '继续 OHOS 动态照片重新匹配失败',
          pause: '暂停 OHOS 动态照片重新匹配失败',
          cancel: '终止 OHOS 动态照片重新匹配失败',
        }[action],
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
      <QueueCardBadge color="success">运行中</QueueCardBadge>
    {:else if isPaused}
      <QueueCardBadge color="warning">已暂停</QueueCardBadge>
    {:else if rescanState?.status === 'canceled'}
      <QueueCardBadge color="warning">已终止</QueueCardBadge>
    {:else if rescanState?.status === 'failed'}
      <QueueCardBadge color="warning">失败</QueueCardBadge>
    {/if}

    <div class="flex flex-col gap-2 p-5 sm:p-7 md:p-9">
      <div class="flex items-center gap-2 text-xl font-semibold text-primary">
        <Icon icon={mdiImageRefreshOutline} size="1.25em" class="hidden shrink-0 sm:block" />
        <span>OHOS 动态照片重新匹配</span>
      </div>

      <div class="text-sm whitespace-pre-line dark:text-white">
        重新匹配 OHOS 动态照片的照片/视频文件。AI 云增强照片的 XtStyle
        标记只作为疑似项检查；如果没有对应视频，不计入缺失配对。
      </div>

      {#if rescanState}
        <div class="mt-2 h-2 w-full max-w-md overflow-hidden rounded-full bg-gray-300 dark:bg-gray-700">
          <div class="h-full bg-immich-primary dark:bg-immich-dark-primary" style={`width: ${progress}%`}></div>
        </div>

        <div class="mt-2 flex w-full max-w-md flex-col sm:flex-row">
          <div
            class="flex w-full place-items-center justify-between rounded-t-lg bg-immich-primary px-6 py-2 text-white sm:rounded-s-lg sm:rounded-e-none sm:py-4 dark:bg-immich-dark-primary dark:text-immich-dark-gray"
          >
            <p>已扫描</p>
            <p class="text-2xl">
              {rescanState.scanned}
            </p>
          </div>

          <div
            class="flex w-full flex-row-reverse place-items-center justify-between rounded-b-lg bg-gray-200 px-6 py-2 text-immich-dark-bg sm:rounded-s-none sm:rounded-e-lg sm:py-4 dark:bg-gray-700 dark:text-immich-gray"
          >
            <p class="text-2xl">
              {rescanState.total ?? '-'}
            </p>
            <p>总数</p>
          </div>
        </div>

        <div class="mt-2 grid grid-cols-2 gap-3 text-sm md:grid-cols-3">
          <div>
            <p class="text-gray-500 dark:text-gray-400">检测到标记文件</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.detected}</p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">匹配成功</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">
              {rescanState.matched} 新增，{rescanState.alreadyMatched} 已存在
            </p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">缺失配对</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.missing}</p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">已跳过</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{rescanState.skipped}</p>
          </div>
          <div>
            <p class="text-gray-500 dark:text-gray-400">失败</p>
            <p class="font-medium text-gray-900 dark:text-gray-100">{failures.length}</p>
          </div>
        </div>

        {#if rescanState.current}
          <div class="mt-2 rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
            <p class="font-medium">{stageLabel(rescanState.current.stage)}: {rescanState.current.assetId}</p>
            <p class="mt-1 break-all">{rescanState.current.originalPath}</p>
          </div>
        {/if}

        {#if failures.length > 0}
          <div class="mt-2 rounded-lg bg-gray-200 p-3 text-xs text-gray-700 dark:bg-gray-700 dark:text-gray-200">
            <p class="mb-2 font-medium">最近失败项</p>
            <div class="flex flex-col gap-2">
              {#each failures.slice(0, 5) as failure (failure.assetId)}
                <div>
                  <p class="break-all">{failure.originalPath}</p>
                  <p class="text-gray-500 dark:text-gray-400">
                    {stageLabel(failure.stage)}: {failure.reason}（尝试次数：{failure.attempts}）
                  </p>
                </div>
              {/each}
            </div>
          </div>
        {/if}
      {:else if loading}
        <p class="text-sm text-gray-600 dark:text-gray-300">加载中...</p>
      {/if}
    </div>
  </div>

  <div class="flex w-full flex-row overflow-hidden sm:w-32 sm:flex-col">
    {#if isActive}
      <QueueCardButton disabled={submitting} color="dark-gray" onClick={() => updateRescan('pause')}>
        <Icon icon={mdiPause} size="24" />
        <span>暂停</span>
      </QueueCardButton>
      <QueueCardButton disabled={submitting} color="light-gray" onClick={() => updateRescan('cancel')}>
        <Icon icon={mdiStop} size="24" />
        <span>终止</span>
      </QueueCardButton>
    {:else if isPaused}
      <QueueCardButton disabled={submitting} color="dark-gray" onClick={() => updateRescan('resume')}>
        <Icon icon={mdiPlay} size="24" />
        <span>继续</span>
      </QueueCardButton>
      <QueueCardButton disabled={submitting} color="light-gray" onClick={() => updateRescan('cancel')}>
        <Icon icon={mdiStop} size="24" />
        <span>终止</span>
      </QueueCardButton>
    {:else}
      <QueueCardButton color="dark-gray" disabled={submitting} onClick={() => queueRescan(false)}>
        <Icon icon={mdiImageRefreshOutline} size="24" />
        <span>全部</span>
      </QueueCardButton>
      <QueueCardButton
        color="light-gray"
        disabled={submitting || failures.length === 0}
        onClick={() => queueRescan(true)}
      >
        <Icon icon={mdiReplay} size="24" />
        <span>缺失</span>
      </QueueCardButton>
    {/if}
  </div>
</div>
