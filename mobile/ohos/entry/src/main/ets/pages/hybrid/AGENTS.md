# AGENTS.md

## Hybrid timeline scope

- This file applies to the ArkUI hybrid timeline under:
  - `F:\immich_ohos\mobile\ohos\entry\src\main\ets\pages\hybrid`
- The current active hybrid timeline entry path is:
  - `PhotoGridPage -> PhotoGridBasePage -> PhotoGridViewBuilder -> TimelinePageLoader -> TimelineView`
- The legacy `HybridPhotoGrid*` experimental implementations have been removed from this directory.

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
- Treat the active multi-form/FSM path as the only source of truth for timeline behavior unless a new alternative path is explicitly introduced.

## Validation

- Validate hybrid timeline changes from:
  - `F:\immich_ohos\mobile`
- Preferred build and run method:
  - use codegenie MCP build via `mcp_codegenie-mcp_build_project`
  - use codegenie MCP app launch via `mcp_codegenie-mcp_start_app`
  - prefer `build_intent: 'Release'` for hybrid timeline validation unless the task needs another intent
- When a codegenie build writes a large output artifact file, determine success from a terminal tail first:
  - run `Get-Content <codegenie-output-file> -Tail 30 | Out-String`
  - use the tail result to check for final `BUILD SUCCESSFUL` / failure lines instead of reading the full artifact file first
- Do not use terminal `flutter build hap --release`, `flutter run`, `hdc install`, `hdc shell aa start`, or workspace build/run tasks for routine hybrid timeline validation unless explicitly requested.

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

- Build from repo root with codegenie MCP:
  - `mcp_codegenie-mcp_build_project` with `build_intent: 'Release'`
- For routine launch/run, start the app with codegenie MCP:
  - `mcp_codegenie-mcp_start_app`
  - unless the task requires another target, use the default `entry` / `EntryAbility` / `default`
- Only use the stress script's install/launch flags when the stress run specifically needs a fresh install and automated launch.
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
  means the timeline still has a real performance problem even when hitch counters stay at zero.
