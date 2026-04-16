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