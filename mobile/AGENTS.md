# AGENTS.md

## Environment

- Huawei DevEco Studio SDK path:
  - `C:\Program Files\Huawei\DevEco Studio\sdk\default`
- If `DEVECO_SDK_HOME` is configured externally, it must point to:
  - `C:\Program Files\Huawei\DevEco Studio\sdk`
- Do not point `DEVECO_SDK_HOME` to:
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
- Use explicit types instead of `any` or `unknown` to satisfy `arkts-no-any-unknown`.
- Do not use destructuring in ArkTS code. Avoid object destructuring, array destructuring, and destructured parameters.
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

## ArkTS language constraints

- Object literals cannot be used as type declarations in ArkTS (`arkts-no-obj-literals-as-types`).
  - Instead of `(info: { receiveSize: number; totalSize: number })`, define a named `interface` and use that.
- Always define named interfaces for callback parameter types, function return shapes, and structured objects.
- Do not use `any` or `unknown` in ArkTS (`arkts-no-any-unknown`).
  - Always add explicit concrete types for locals, callback parameters, return values, and intermediate values from `Map.get(...)` / `MethodCall` arguments.
  - When the shape is known, prefer concrete maps like `Map<string, number>` / `Map<string, string>` instead of `ESObject`-typed locals.

## Validation

- If a build or check requires Huawei OHOS SDK, use:
  - `C:\Program Files\Huawei\DevEco Studio\sdk\default`
- For OHOS ArkTS or hybrid timeline changes, validate from:
  - `F:\immich_ohos\mobile`
- Preferred OHOS build and run method:
  - use codegenie MCP build via `mcp_codegenie-mcp_build_project`
  - use codegenie MCP app launch via `mcp_codegenie-mcp_start_app`
  - prefer `build_intent: 'Release'` for release validation unless the task needs another intent
- When a codegenie build writes a large output artifact file, determine success from a terminal tail first:
  - run `Get-Content <codegenie-output-file> -Tail 30 | Out-String`
  - use the tail result to check for final `BUILD SUCCESSFUL` / failure lines instead of reading the full artifact file first
- Do not use terminal commands, `flutter run`, `hdc install`, `hdc shell aa start`, or workspace build/run tasks for routine OHOS validation unless explicitly requested.
- Before using `codegenie_mcp` to check ArkTS syntax, `git add` every newly created `.ets` file first.
  - Newly added untracked `.ets` files may be skipped by `codegenie_mcp` until they are staged.
- If the codegenie MCP build fails, clearly distinguish:
  - code or ArkTS compilation failures
  - signing, certificate, or local toolchain/environment failures
- Before finishing, clearly report:
  - which files were changed
  - whether any file under the forbidden path was touched
  - whether the change was for old timeline or beta timeline
