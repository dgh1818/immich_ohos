# AGENTS.md

## Upstream Alignment

- Keep changes as close to upstream as possible.
- Prefer the smallest necessary patch.
- Do not introduce unnecessary abstractions, wrappers, or local deviations from upstream behavior.
- Do not rewrite upstream logic unless required for the task.

## NetStack 修复后的 NetworkKit 切换

- 当前 HDR 交付线继续使用 libcurl,不得仅因为 OpenHarmony/GitCode 源码已经合入修复就切回 NetworkKit。只有修复已经进入目标手机的系统固件,并在该固件上验证 `requestInStream` + `multiFormDataList` 同时传入 `filePath` 和 `remoteFileName` 时仍通过文件路径流式上传,才允许开始切换。
- 系统回归必须包含一个大于 2 GiB 的真实视频 multipart 上传,并确认上传进度持续推进、应用及系统网络进程无 OOM/崩溃、服务端可正确解析响应。CI、编译通过、小文件测试或只检查 OpenHarmony 源码均不能替代此真机回归。
- 切换时以以下备份分支作为 NetworkKit 实现参考:
  - `F:\immich_ohos\mobile`: `backup/networkkit-native-bridge-20260825`
  - `F:\package_flutter\ohos_http`: `backup/networkkit-native-bridge-20260825`
  - `F:\package_flutter\background_downloader_ohos`: `backup/networkkit-ohos-http-20260825`
- 不得直接把三个仓库整体重置或长期切回上述旧备份分支。应从届时各仓库的最新交付分支新建切换分支,逐项对照并迁移 NetworkKit 实现,保留备份分支创建后新增的 HDR 功能、上游合并和 bug 修复。
- 切换目标是 `ohos_http` 不再打包 libcurl、`background_downloader_ohos` 只依赖 `ohos_http` 的系统 HTTP 能力、HDR 安装包不包含 x86 模拟器原生库。不得重新引入大于 2 GiB 时改走 `request.uploadFile` 的分流。
- 迁移时必须保留并重新验证自签名 CA、跳过服务端证书校验、P12 客户端证书及密码透传;Worker 必须使用 `ApplicationContext` 对应的应用级 `filesDir`,与 `ssl_client_cert` 及 cache 目录的创建位置一致,不得退回曾经错误的 UIContext/cache 路径解析。
- 切换后的 release HAP 必须实际解包确认不含 `libcurl.so*`、x86 原生库和 `integration_test.har`,然后安装到目标真机,完成登录/同步、后台备份、超大视频上传和自签名服务器回归。验证未全部完成时不得把 NetworkKit 切换标记为完成。

## Merging Upstream Tags (OHOS)

- 上游 merge 可能**在无任何冲突标记的情况下**覆盖掉 OHOS 本地修复(上游代码"看起来正常"就被接受)。merge 是否干净不代表安全,以下文件每次 merge 后必须人工 diff,禁止只看冲突标记。
- 教训案例:2026-06-21 `9930b0de8` merge v3.0.0-rc.0 时,上游 #27666 把 `_performPause()` 改成无条件 `stopForegroundBackup()`,静默冲掉 2026-02-08 `e92357e0f` 的修复,导致退后台备份即死,后续所有构建带病。

### P0 命门文件(每次 merge 必查)

| 文件 | 检查点 |
|---|---|
| `mobile/lib/providers/app_life_cycle.provider.dart` | `_performPause()` 里 OHOS 必须跳过 `stopForegroundBackup()`(`if (!CurrentPlatform.isOhos)` 保护是否还在);`_shouldContinueOperation()` 对 OHOS 放行 paused/hidden |
| `mobile/lib/providers/backup/drift_backup.provider.dart` | `_startOhosBackgroundTransfer/_stopOhosBackgroundTransfer/_updateOhosBackgroundTransferProgress` 三方法及调用点是否保留;`_stopOhos...` 的 `checkActiveTasks` 保护是否被上游覆盖 |
| `mobile/lib/domain/services/hash.service.dart` | `_startedBackgroundTransfer` 保活启停逻辑(hash 期间长时任务续命)是否保留 |
| `mobile/lib/domain/services/background_worker.service.dart` | OHOS 分流必须仍是 `startBackupWithURLSession`(iOS 式 enqueue + 回调),不得被改成安卓式 `uploadCandidates` |
| `mobile/ohos/entry/src/main/module.json5` | EntryAbility 的 `backgroundModes: ["dataTransfer"]` 是否保留 |
| `mobile/ohos/.../plugins/sync/MessagesImplBase.ets` | `startBackgroundTransfer/updateBackgroundTransferProgress/stopBackgroundTransfer` 三件套 + wantAgent 回跳 + `lastLiveNotificationUpdatedAt` 节流是否保留 |
| `mobile/ohos/.../entryability/EntryAbility.ets` | 插件注册(`NativeSyncApiOhos.setup(...)` 等)是否齐全 |

### P1(merge 后抽查)

- `mobile/ohos/.../plugins/connectivity/ConnectivityApiImpl.ets`:`isUnmetered` 必须包含 `bearerTypes.includes(BEARER_WIFI)` 判定。OHOS 系统只给 VPN/穿戴分布式网络报 `NET_CAPABILITY_NOT_METERED`,WiFi 默认网络不报(caps 实测 `[12,15,16]`);只信 caps 会导致 WiFi 下永远被判计费 → 不开"蜂窝备份"就不上传

- `mobile/pubspec.yaml` 的 `photo_manager` git ref:必须指向 fork(`dgh1818/flutter_photo_manager`)中含 `68089cb`(OHOS `deleteAssets` 单次上限 300 的分片修复,在 `PhotoAssetHandler.ets` 的 deleteWithIds/moveToTrash)或之后的提交,不得换回 pub.dev 版;immich 侧 `asset_media.repository.dart` 的 `deleteAll()` 保持上游原样(分片在插件 native 层)
- `mobile/lib/repositories/upload.repository.dart`:`Platform.isOhos` 的 `OhosMultipartRequest`(filePath 直传)分支是否保留
- `mobile/pubspec.yaml` + `mobile/ohos/oh-package.json5`:`background_downloader` 等 OHOS override(`../../package_flutter/...` 与 `file:./har/*.har`)是否被升级冲掉

### 冲突解决原则

1. `app_life_cycle.provider.dart` 出现 backup/stop 相关 diff → 一律保留本分支版本,逐行对照上表
2. 上游重构 backup 编排 → 先 `git log -S "stopForegroundBackup" -- mobile/lib/providers/` 考古再决定
3. merge 后必做真机回归:开备份 → 立刻退后台锁屏 → 2 分钟内看通知进度是否推进(30 秒即可暴露 P0 问题)
4. 每次成功 merge 后,把新增命门点补进本节
