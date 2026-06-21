# AGENTS.md

## Environment

- Huawei DevEco Studio SDK path:
  - `C:\Program Files\Huawei\DevEco Studio\sdk\default`

## Flutter engine OHOS artifacts

- The WSL engine source of truth is:
  - `/home/dgh18/engine_3.41/engine`
- Build OHOS release engine artifacts from WSL with the Linux OHOS SDK environment loaded, for example:
  - `wsl -e bash -ic 'cd /home/dgh18/engine_3.41/engine && ./ohos -t release'`
- After rebuilding the WSL OHOS release engine, replace the FVM release artifact used by mobile builds:
  - `F:\fvm\versions\custom_3.41.9\bin\cache\artifacts\engine\ohos-arm64-release\flutter.har`
- Normal `flutter build hap` should use the FVM release artifact and sync the mobile project HAR:
  - `F:\immich_ohos\mobile\ohos\har\flutter.har`

## Plugin source of truth

- The active `background_downloader_ohos` plugin source is located at:
  - `F:\package_flutter\background_downloader_ohos`
- The active `ohos_http` plugin source is located at:
  - `F:\package_flutter\ohos_http`
- When changing `ohos_http` native C++ code, rebuild the plugin's `ohos/libs/arm64-v8a/libohos_http_ffi.so`; Flutter builds load that prebuilt library and do not automatically pick up source-only C++ edits.

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
- When running `flutter test` / Flutter tester with proxy environment variables set, ensure localhost bypasses the proxy:
  - PowerShell example: `$env:NO_PROXY='127.0.0.1,localhost,::1'; $env:no_proxy=$env:NO_PROXY; fvm flutter test ...`
  - Without this, the tester's local WebSocket connection to the Flutter tool can fail with `HttpException: Connection closed before full header was received`.
- Before finishing, clearly report:
  - which files were changed
  - whether any file under the forbidden path was touched
  - whether the change was for old timeline or beta timeline

## OHOS sqlite3 v3

- For `sqlite3` v3 on OHOS, use `hooks.user_defines.sqlite3.source: system` in the mobile `pubspec.yaml` and keep the OHOS dependency `"sqlite3-native-library": "3.53.0"` in `ohos/oh-package.json5`.
- Do not re-add `sqlite3_flutter_libs` for the v3 path unless explicitly reverting to the old sqlite3 2.x plugin flow.
- Do not call `package:sqlite3` global native variables such as `sqlite3.tempDirectory` on OHOS. That path resolves `sqlite3_temp_directory` through Dart native-assets and can fail with `No available native assets`; prefer the `sqlite_async/native.dart` connection path backed by the OHOS `sqlite3-native-library`.
- Keep `configureSqliteCache()` returning early on OHOS. Immich already opens sqlite through `sqlite_async/native.dart` with `PRAGMA temp_store = MEMORY`; setting `sqlite3.tempDirectory` on OHOS is unnecessary and can trigger native-assets symbol resolution failures.
- Upstream Immich stores the Drift databases under `getApplicationDocumentsDirectory()` as `immich.sqlite` and `immich_logs.sqlite`; this repo keeps that path. On the current OHOS `path_provider_ohos`, that maps through Flutter-OH `PathUtils.getDataDirectory()` to the app sandbox `context.filesDir/flutter`.
- Keep `NativeAssetsManifest.json` registered as a root Flutter asset until Flutter-OH copies `native_assets.json` into `flutter_assets/NativeAssetsManifest.json` itself. This manifest is required for packages such as `sqlite3_connection_pool` whose `.so` is bundled but still needs a Dart native-assets mapping.
