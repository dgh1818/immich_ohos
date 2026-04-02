# AGENTS.md

## Environment

- Huawei DevEco Studio SDK path:
  - `C:\Program Files\Huawei\DevEco Studio\sdk\default`

## Plugin source of truth

- The active `background_downloader_ohos` plugin source is located at:
  - `F:\package_flutter\background_downloader_ohos`

## Do not modify

- Do NOT modify any files under:
  - `F:\immich_ohos\mobile\ohos\entry\src\main\ets\plugins\background_downloader_ohos`

## Working rules for background_downloader_ohos

- When fixing or analyzing `background_downloader_ohos`, always read and edit the plugin under:
  - `F:\package_flutter\background_downloader_ohos`
- Treat the copy under `F:\immich_ohos\mobile\ohos\entry\src\main\ets\plugins\background_downloader_ohos` as read-only.
- Do not sync changes into the read-only copy unless explicitly requested.

## Flutter plugin change boundary

- When modifying Flutter plugins, avoid changing shared or common cross-platform code unless it is absolutely necessary.
- Prefer limiting changes to the ArkTS implementation whenever possible.
- Do not modify the public Dart API, platform interface, or shared plugin logic unless the task explicitly requires it.
- If a fix can be implemented only in the ArkTS layer, do it there instead of changing common code.
- Only change shared code when the issue cannot be solved safely in the ArkTS implementation alone.

## Timeline architecture

- `immich mobile` currently contains two timeline implementations:
  - old timeline
  - beta timeline
- Any timeline-related code involving `drift` or `presentation` should be considered part of the beta timeline unless explicitly stated otherwise.
- Do not confuse beta timeline code with the old timeline implementation.
- Keep patches scoped to one timeline implementation whenever possible.

## Upstream alignment

- Keep changes as close to upstream as possible.
- Prefer the smallest necessary patch.
- Do not introduce unnecessary abstractions, wrappers, or local deviations from upstream behavior.
- Do not rewrite upstream logic unless required for the task.

## Debugging and bug visibility

- Do not add fallback logic unless explicitly required.
- Do not hide bugs with defensive workarounds that change intended behavior.
- Prefer letting the real bug surface clearly so the root cause can be identified and fixed.
- Prefer fixing the root cause over adding fallback paths.
- Avoid silent failure handling unless upstream already does so.

## Validation

- If a build or check requires Huawei OHOS SDK, use:
  - `C:\Program Files\Huawei\DevEco Studio\sdk\default`
- Before finishing, clearly report:
  - which files were changed
  - whether any file under the forbidden path was touched
  - whether the change was for old timeline or beta timeline
