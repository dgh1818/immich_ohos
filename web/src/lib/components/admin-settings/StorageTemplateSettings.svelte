<script lang="ts">
  import SupportedDatetimePanel from '$lib/components/admin-settings/SupportedDatetimePanel.svelte';
  import SupportedVariablesPanel from '$lib/components/admin-settings/SupportedVariablesPanel.svelte';
  import SettingButtonsRow from '$lib/components/shared-components/settings/SystemConfigButtonRow.svelte';
  import SettingInputField from '$lib/components/shared-components/settings/SettingInputField.svelte';
  import SettingSwitch from '$lib/components/shared-components/settings/SettingSwitch.svelte';
  import { SettingInputFieldType } from '$lib/constants';
  import FormatMessage from '$lib/elements/FormatMessage.svelte';
  import { authManager } from '$lib/managers/auth-manager.svelte';
  import { featureFlagsManager } from '$lib/managers/feature-flags-manager.svelte';
  import { systemConfigManager } from '$lib/managers/system-config-manager.svelte';
  import { Route } from '$lib/route';
  import {
    clearStorageTemplateMigrationFailures,
    getStorageTemplateMigrationState,
    retryStorageTemplateMigrationFailures,
    type StorageTemplateMigrationState,
  } from '$lib/services/storage-template-migration.service';
  import { handleSystemConfigSave } from '$lib/services/system-config.service';
  import { handleError } from '$lib/utils/handle-error';
  import { getStorageTemplateOptions, type SystemConfigTemplateStorageOptionDto } from '@immich/sdk';
  import { Button, Heading, Link, LoadingSpinner, Text, toastManager } from '@immich/ui';
  import handlebar from 'handlebars';
  import * as luxon from 'luxon';
  import { onDestroy, onMount } from 'svelte';
  import { t } from 'svelte-i18n';
  import { createBubbler, preventDefault } from 'svelte/legacy';
  import { fade } from 'svelte/transition';

  type Props = {
    minified?: boolean;
    duration?: number;
    saveOnClose?: boolean;
  };

  const { minified = false, duration = 500, saveOnClose = false }: Props = $props();

  const disabled = $derived(featureFlagsManager.value.configFile);
  const config = $derived(systemConfigManager.value);
  let configToEdit = $state(systemConfigManager.cloneValue());

  const bubble = createBubbler();
  let templateOptions: SystemConfigTemplateStorageOptionDto | undefined = $state();
  let selectedPreset = $state('');
  let migrationState: StorageTemplateMigrationState | undefined = $state();
  let migrationStateLoading = $state(false);

  const getTemplateOptions = async () => {
    templateOptions = await getStorageTemplateOptions();
    selectedPreset = config.storageTemplate.template;
  };

  const getSupportDateTimeFormat = () => getStorageTemplateOptions();

  const renderTemplate = (templateString: string) => {
    if (!templateOptions) {
      return '';
    }

    const template = handlebar.compile(templateString, {
      knownHelpers: undefined,
    });

    const substitutions: Record<string, string> = {
      filename: 'IMAGE_56437',
      ext: 'jpg',
      filetype: 'IMG',
      filetypefull: 'IMAGE',
      assetId: 'a8312960-e277-447d-b4ea-56717ccba856',
      assetIdShort: '56717ccba856',
      album: $t('album_name'),
      make: 'FUJIFILM',
      model: 'X-T50',
      lensModel: 'XF27mm F2.8 R WR',
    };

    const dt = luxon.DateTime.fromISO(new Date('2022-02-03T04:56:05.250').toISOString());
    const albumStartTime = luxon.DateTime.fromISO(new Date('2021-12-31T05:32:41.750').toISOString());
    const albumEndTime = luxon.DateTime.fromISO(new Date('2023-05-06T09:15:17.100').toISOString());

    const dateTokens = [
      ...templateOptions.yearOptions,
      ...templateOptions.monthOptions,
      ...templateOptions.weekOptions,
      ...templateOptions.dayOptions,
      ...templateOptions.hourOptions,
      ...templateOptions.minuteOptions,
      ...templateOptions.secondOptions,
    ];

    for (const token of dateTokens) {
      substitutions[token] = dt.toFormat(token);
      substitutions['album-startDate-' + token] = albumStartTime.toFormat(token);
      substitutions['album-endDate-' + token] = albumEndTime.toFormat(token);
    }

    return template(substitutions);
  };

  const handlePresetSelection = () => {
    configToEdit.storageTemplate.template = selectedPreset;
  };

  const refreshMigrationState = async () => {
    if (minified) {
      return;
    }

    migrationStateLoading = true;
    try {
      migrationState = await getStorageTemplateMigrationState();
    } catch (error) {
      handleError(error, 'Unable to load storage template migration state', { notify: false });
    } finally {
      migrationStateLoading = false;
    }
  };

  const retryFailures = async () => {
    try {
      migrationState = await retryStorageTemplateMigrationFailures();
      toastManager.primary('Queued failed storage template migration items');
    } catch (error) {
      handleError(error, 'Unable to retry failed storage template migration items');
    }
  };

  const clearFailures = async () => {
    try {
      migrationState = await clearStorageTemplateMigrationFailures();
      toastManager.primary('Cleared storage template migration failures');
    } catch (error) {
      handleError(error, 'Unable to clear storage template migration failures');
    }
  };

  let parsedTemplate = $derived(() => {
    try {
      return renderTemplate(configToEdit.storageTemplate.template);
    } catch {
      return 'error';
    }
  });

  onDestroy(async () => {
    if (saveOnClose) {
      await handleSystemConfigSave({ storageTemplate: configToEdit.storageTemplate });
    }
  });

  onMount(() => {
    void refreshMigrationState();
  });
</script>

<section class="mt-2 dark:text-immich-dark-fg">
  <div in:fade={{ duration }} class="mx-4 flex flex-col gap-4 py-4">
    <p class="text-sm dark:text-immich-dark-fg">
      <FormatMessage key="admin.storage_template_more_details">
        {#snippet children({ tag, message })}
          {#if tag === 'template-link'}
            <Link href="https://docs.immich.app/administration/storage-template">{message}</Link>
          {:else if tag === 'implications-link'}
            <Link href="https://docs.immich.app/administration/backup-and-restore#asset-types-and-storage-locations">
              {message}
            </Link>
          {/if}
        {/snippet}
      </FormatMessage>
    </p>
  </div>
  {#await getTemplateOptions() then}
    <div id="directory-path-builder" class="flex flex-col gap-4 {minified ? '' : 'ms-4 mt-4'}">
      <SettingSwitch
        title={$t('admin.storage_template_enable_description')}
        {disabled}
        bind:checked={configToEdit.storageTemplate.enabled}
        isEdited={!(configToEdit.storageTemplate.enabled === config.storageTemplate.enabled)}
      />

      {#if !minified}
        <SettingSwitch
          title={$t('admin.storage_template_hash_verification_enabled')}
          {disabled}
          subtitle={$t('admin.storage_template_hash_verification_enabled_description')}
          bind:checked={configToEdit.storageTemplate.hashVerificationEnabled}
          isEdited={!(
            configToEdit.storageTemplate.hashVerificationEnabled === config.storageTemplate.hashVerificationEnabled
          )}
        />
      {/if}

      {#if configToEdit.storageTemplate.enabled}
        <hr />

        <Heading size="tiny" color="primary">
          {$t('variables')}
        </Heading>

        <section class="support-date">
          {#await getSupportDateTimeFormat()}
            <LoadingSpinner />
          {:then options}
            <div transition:fade={{ duration: 200 }}>
              <SupportedDatetimePanel {options} />
            </div>
          {/await}
        </section>

        <section class="support-date">
          <SupportedVariablesPanel />
        </section>

        <div class="mt-2 flex flex-col">
          <!-- <h3 class="text-base font-medium text-primary">{$t('template')}</h3> -->
          <Heading size="tiny" color="primary">
            {$t('template')}
          </Heading>

          <div class="my-2">
            <Text size="small">{$t('preview')}</Text>
          </div>

          <p class="text-sm">
            <FormatMessage
              key="admin.storage_template_path_length"
              values={{
                length: parsedTemplate().length + authManager.user.id.length + 'UPLOAD_LOCATION'.length,
                limit: 260,
              }}
            >
              {#snippet children({ message })}
                <span class="font-semibold text-primary">{message}</span>
              {/snippet}
            </FormatMessage>
          </p>

          <p class="text-sm">
            <FormatMessage
              key="admin.storage_template_user_label"
              values={{ label: authManager.user.storageLabel || authManager.user.id }}
            >
              {#snippet children({ message })}
                <code class="text-primary">{message}</code>
              {/snippet}
            </FormatMessage>
          </p>

          <p class="mt-2 rounded-lg bg-gray-200 p-4 py-2 text-xs dark:bg-gray-700 dark:text-immich-dark-fg">
            <span class="text-immich-fg/25 dark:text-immich-dark-fg/50"
              >UPLOAD_LOCATION/library/{authManager.user.storageLabel || authManager.user.id}</span
            >/{parsedTemplate()}.jpg
          </p>

          <form autocomplete="off" class="flex flex-col" onsubmit={preventDefault(bubble('submit'))}>
            <div class="my-2 flex flex-col">
              {#if templateOptions}
                <label class="text-sm font-medium text-primary" for="preset-select">
                  {$t('preset')}
                </label>
                <select
                  class="mt-2 immich-form-input rounded-lg bg-slate-200 p-2 text-sm hover:cursor-pointer dark:bg-gray-600"
                  disabled={disabled || !configToEdit.storageTemplate.enabled}
                  name="presets"
                  id="preset-select"
                  bind:value={selectedPreset}
                  onchange={handlePresetSelection}
                >
                  {#each templateOptions.presetOptions as preset (preset)}
                    <option value={preset}>{renderTemplate(preset)}</option>
                  {/each}
                </select>
              {/if}
            </div>

            <div class="flex gap-2 align-bottom">
              <SettingInputField
                label={$t('template')}
                disabled={disabled || !configToEdit.storageTemplate.enabled}
                required
                inputType={SettingInputFieldType.TEXT}
                bind:value={configToEdit.storageTemplate.template}
                isEdited={!(configToEdit.storageTemplate.template === config.storageTemplate.template)}
              />

              <div class="flex-0">
                <SettingInputField
                  label={$t('extension')}
                  inputType={SettingInputFieldType.TEXT}
                  value=".jpg"
                  disabled
                />
              </div>
            </div>

            {#if !minified}
              <div id="migration-info" class="mt-2 text-sm">
                <Heading size="tiny" color="primary">
                  {$t('notes')}
                </Heading>
                <section class="flex flex-col gap-2">
                  <p>
                    <FormatMessage
                      key="admin.storage_template_migration_info"
                      values={{ job: $t('admin.storage_template_migration_job') }}
                    >
                      {#snippet children({ message })}
                        <a href={Route.queues()} class="text-primary">{message}</a>
                      {/snippet}
                    </FormatMessage>
                  </p>
                </section>
                <section class="mt-4 flex flex-col gap-3 rounded-lg bg-gray-100 p-4 dark:bg-gray-800">
                  <div class="flex flex-wrap items-center justify-between gap-2">
                    <Heading size="tiny" color="primary">Storage template migration status</Heading>
                    <div class="flex gap-2">
                      <Button
                        size="tiny"
                        color="secondary"
                        disabled={migrationStateLoading}
                        onclick={refreshMigrationState}>Refresh</Button
                      >
                      <Button
                        size="tiny"
                        disabled={migrationStateLoading || !migrationState?.failures?.length}
                        onclick={retryFailures}>Retry failed</Button
                      >
                      <Button
                        size="tiny"
                        color="danger"
                        disabled={migrationStateLoading || !migrationState?.failures?.length}
                        onclick={clearFailures}>Clear failed</Button
                      >
                    </div>
                  </div>

                  {#if migrationState}
                    <div class="grid gap-1 text-xs">
                      <span>Scanned: {migrationState.scanned ?? 0}</span>
                      <span>Failed: {migrationState.failed ?? migrationState.failures?.length ?? 0}</span>
                      {#if migrationState.completedAt}
                        <span>Completed: {migrationState.completedAt}</span>
                      {:else if migrationState.startedAt}
                        <span>Started: {migrationState.startedAt}</span>
                      {/if}
                    </div>

                    {#if migrationState.current}
                      <div class="rounded bg-white p-3 text-xs dark:bg-gray-900">
                        <div class="font-semibold text-primary">Current item</div>
                        <div>Stage: {migrationState.current.stage}</div>
                        <div>Asset: {migrationState.current.assetId}</div>
                        <div class="break-all">Old: {migrationState.current.originalPath}</div>
                        {#if migrationState.current.targetPath}
                          <div class="break-all">New: {migrationState.current.targetPath}</div>
                        {/if}
                      </div>
                    {/if}

                    {#if migrationState.failures?.length}
                      <div class="max-h-80 overflow-auto rounded bg-white p-3 text-xs dark:bg-gray-900">
                        <div class="mb-2 font-semibold text-red-600 dark:text-red-400">Failed items</div>
                        <div class="flex flex-col gap-3">
                          {#each migrationState.failures as failure (`${failure.assetId}-${failure.stage}-${failure.originalPath}`)}
                            <div class="border-b border-gray-200 pb-2 last:border-b-0 dark:border-gray-700">
                              <div class="font-semibold">
                                {failure.stage} - {failure.assetId}
                                {#if failure.timedOut}
                                  <span class="text-red-600 dark:text-red-400">(timeout)</span>
                                {/if}
                              </div>
                              <div>Attempts: {failure.attempts}</div>
                              {#if failure.retryAssetId && failure.retryAssetId !== failure.assetId}
                                <div>Retry asset: {failure.retryAssetId}</div>
                              {/if}
                              <div>Failed: {failure.failedAt}</div>
                              <div class="break-all">Reason: {failure.reason}</div>
                              <div class="break-all">Old: {failure.originalPath}</div>
                              {#if failure.targetPath}
                                <div class="break-all">New: {failure.targetPath}</div>
                              {/if}
                            </div>
                          {/each}
                        </div>
                      </div>
                    {/if}
                  {:else if migrationStateLoading}
                    <LoadingSpinner />
                  {/if}
                </section>
              </div>
            {/if}
          </form>
        </div>
      {/if}

      {#if !minified}
        <SettingButtonsRow bind:configToEdit keys={['storageTemplate']} {disabled} />
      {/if}
    </div>
  {/await}
</section>
