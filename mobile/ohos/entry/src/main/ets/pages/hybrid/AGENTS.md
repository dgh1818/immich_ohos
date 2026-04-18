# AGENTS.md

## Hybrid timeline scope

- This file applies to the ArkUI hybrid timeline under:
  - `F:\immich_ohos\mobile\ohos\entry\src\main\ets\pages\hybrid`
- The current active hybrid timeline entry path is:
  - `PhotoGridPage -> PhotoGridBasePage -> PhotoGridViewBuilder -> TimelinePageLoader -> TimelineView`
- The `HybridPhotoGridView` / `HybridPhotoGridVm` 3-grid pipeline exists in the same directory, but it is not the current active entry path.

## Alignment target

- The user-provided reference app root is:
  - `F:\immich_ohos\.tmp\applications_photos_ref\product\phone\src\main\ets`
- The timeline-specific reference implementation to align against is:
  - `F:\immich_ohos\.tmp\applications_photos_ref\feature\timeline\src\main\ets\photogrid`
- Keep the hybrid timeline as close to the reference implementation as possible to reduce divergence and bugs.

## Working focus

- For timeline alignment and bug fixing, prioritize the active multi-form/FSM path:
  - `TimelineView`
  - `PhotoGridViewModel`
  - `YearGridView`
  - `MonthGridView`
  - `DayGridView`
  - `GroupGridView`
- Unless explicitly requested, do not treat the inactive 3-grid path as the source of truth for timeline behavior.

## Validation

- Validate hybrid timeline changes from:
  - `F:\immich_ohos\mobile`
- Preferred build command:
  - `flutter build hap --release`
- Do not prepend the build command with an inline PowerShell environment assignment such as:
  - `{ $env:DEVECO_SDK_HOME = 'C:\Program Files\Huawei\DevEco Studio\sdk' }`
- If the plain `flutter build hap --release` command succeeds, ignore warnings about missing `DEVECO_SDK_HOME`.

## Automated timeline stress test

- For hybrid timeline scroll regressions, use logs, memory, and RenderService stats as the primary signal.
- Screenshots are only auxiliary evidence. Do not use screenshots as the main pass/fail criterion for white-block or jank analysis.
- For downward-scroll validation, make the down phase cover at least `10` full screens. Adjust `DownFlingCount` and `DownStepLength` so the total downward travel is not shorter than that.
- Always run the stress test after the app has finished the local sync startup phase.
- The currently verified ready log is:
  - `isKeepScreenOn: 0`
- If that log is not available in the current run, fall back to waiting:
  - `60` seconds after app launch

## Recommended test sequence

- Build from repo root:
  - `flutter build hap --release`
- Install and launch on device before running the stress script.
- Keep the device awake before and during the test:
  - `power-shell wakeup`
  - `power-shell timeout -o 3600000`
- Clear `hilog` before launch when testing a fresh run:
  - `hdc shell hilog -r`
- Launch the app, then wait for:
  - `isKeepScreenOn: 0`
- After the ready signal, run the stress script:
  - `F:\immich_ohos\mobile\scripts\ohos_timeline_burst_test.ps1`

## Current stress command

- Verified pressure parameters for reproducing timeline issues:
  - `& 'F:\immich_ohos\mobile\scripts\ohos_timeline_burst_test.ps1' -SkipHilogReset -ReadyLogTimeoutSeconds 90 -DownFlingCount 15 -DownVelocity 34000 -DownStepLength 1900 -UpFlingCount 10 -UpVelocity 34000 -UpStepLength 1900`
- For memory-focused runs where screenshots are not needed:
  - set `-BurstFrames 0`

## What to inspect

- Primary output directory:
  - `F:\immich_ohos\mobile\tmp\timeline_burst_test\<timestamp>`
- Inspect these files first:
  - `summary.txt`
  - `timeline_hilog.txt`
  - `render_service_hitchs.txt`
  - `process_before_mem.txt`
  - `process_after_mem.txt`
  - `process_after_cpuusage.txt`
- If `render_service_fps.txt` only contains the header without per-window numbers, do not treat that as a pass result.
- In that case, rely on:
  - `render_service_hitchs.txt`
  - process memory deltas
  - `hilog` warnings

## Key log patterns

- Regressions currently correlate most strongly with:
  - `Use repeat key`
  - `Sliding window updated`
- Also record but do not over-interpret in isolation:
  - `JPEGHWDECODER`
  - `CreatePixelMap success`

## Current interpretation guidance

- `Sliding window updated` is expected during fast scrolling, but very high counts indicate the window is being shifted too frequently.
- Repeated `Use repeat key` warnings are not expected and should be treated as a real signal of datasource/UI reconciliation instability.
- `RenderService hitchs = 0` does not prove the timeline is healthy if:
  - `Use repeat key` remains high
  - memory spikes sharply during the stress run
- A large memory jump after stress, especially in:
  - `ark ts heap`
  - `Graph`
  means the timeline still has a real performance problem even when hitch counters stay at zero.codegenie
