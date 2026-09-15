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

## Flutter OHOS 引擎构建

- 引擎(WSL `~/engine_3.44.9`)一律用仓库自带的 `./ohos -t release` 构建,不得手工拼 ninja/out 目录或另写构建命令。构建产物同步进 `mobile/ohos/har/flutter.har` 后再构建 HAP;装机前必须确认源码 mtime 早于 HAP 构建时间,禁止把旧构建当新版安装。

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

## HarmonyOS 真机录屏与证据采集

- 录制 Immich OHOS 真机用户操作时，使用 HDC 调用系统 ScreenRecorder `ServiceExtAbility`。不要使用 Android 风格的 `hdc shell screenrecord`；该命令在当前 MatePad Pro（HarmonyOS 6.1.0.135）上不可用。DevEco CLI 的 `ui screenshot` 只负责单帧截图，不能替代 MP4 录屏。
- 先确认目标设备。所有后续命令都必须通过 `-t <serial>` 指定设备，不要把某一台设备的 serial 固化到脚本或文档中：

  ```powershell
  $hdc = 'C:\Program Files\Huawei\DevEco Studio\sdk\default\openharmony\toolchains\hdc.exe'
  & $hdc list targets
  ```

- 开始录屏。文件名应使用唯一值，例如 `immich-map-20260902-153000.mp4`。命令成功后，屏幕左上角必须出现系统红色录屏按钮和计时器；这是“真正开始录屏”的验收标志：

  ```powershell
  & $hdc -t <serial> shell aa start -b com.huawei.hmos.screenrecorder -a com.huawei.hmos.screenrecorder.ServiceExtAbility --ps CustomizedFileName <name>.mp4
  ```

- 停止录屏。停止时再次调用同一个 ServiceExtAbility，但不传文件名：

  ```powershell
  & $hdc -t <serial> shell aa start -b com.huawei.hmos.screenrecorder -a com.huawei.hmos.screenrecorder.ServiceExtAbility
  ```

- 查询并拉回录屏文件。`mediatool query` 返回的完整 `file://media/...` URI 是唯一可信的媒体路径；不要自行猜测或拼接媒体库路径。先创建本地证据目录，再把 query 返回的 URI 原样传给 `mediatool recv`：

  ```powershell
  & $hdc -t <serial> shell mediatool query <name>.mp4 -u
  # 将下面的 URI 替换为上一个命令实际返回的完整值
  & $hdc -t <serial> shell mediatool recv "file://media/Photo/<...>/<name>.mp4" /data/local/tmp/<name>.mp4
  & $hdc -t <serial> file recv /data/local/tmp/<name>.mp4 <local-output>.mp4
  ```

- 验收拉回的 MP4。必须确认文件非空、`duration > 0`、存在视频流，并记录设备 serial、实际安装的 HAP/Engine 版本、操作时间、复现步骤和证据文件路径：

  ```powershell
  ffprobe -v error -show_entries format=filename,duration,size:stream=index,codec_name,width,height,avg_frame_rate,nb_frames -of default=noprint_wrappers=1 <local-output>.mp4
  ```

  没有系统录屏指示器、只有几张截图帧，或 MP4 没有有效视频流时，不得称为“已完成录屏”。录屏证据应保存到 `device-test/` 等证据目录，不要提交到源码目录或 HAP 目录。

  **录屏是 HDR/花屏类显示问题的首选取证手段**：`snapshot_display`/`devecocli ui screenshot` 走截屏服务，在 HDR surface 或色彩空间异常时可能产生伪影或漏掉真实显示内容；系统录屏来自合成器管线，可信。逐帧分析流程：`ffprobe` 确认流有效 → `ffmpeg -ss <秒> -t <时长> -i <rec.mp4> -vf fps=<2> frames/t_%02d.png` 抽帧 → 逐帧读图对比转场/亮度跳变。注意 `hdc file recv` 的本地目标路径必须用 Windows 反斜杠绝对路径，否则会被 MSYS 前缀拼接。
- DevEco CLI 可用于单帧截图：

  ```powershell
  devecocli ui screenshot --device <serial> --path <local-png-or-jpg>
  ```

- 如需分析“拖动进度条时手指尚未释放”的中间状态，可在单独进程执行 HDC UI swipe，并在该进程退出前调用 `snapshot_display` 或 `devecocli ui screenshot` 保存中间帧：

  ```text
  hdc -t <serial> shell uitest uiInput swipe <x1> <y1> <x2> <y2> <velocity>
  ```

  `velocity` 使用设备支持的有效范围（当前命令帮助给出的范围为 200–40000）。中间帧仅用于诊断手势过程，完整用户操作仍以系统 MP4 为准。
- 录屏、构建、安装和运行时视觉验收是不同证据层级：必须先明确实际安装的 HAP/Engine 版本，再录制实际设备上的操作；不能用构建成功或安装成功替代录屏和用户可见状态的验收。
