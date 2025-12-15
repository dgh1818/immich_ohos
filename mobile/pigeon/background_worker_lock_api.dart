import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/platform/background_worker_lock_api.g.dart',
    kotlinOut: 'android/app/src/main/kotlin/app/alextran/immich/background/BackgroundWorkerLock.g.kt',
    kotlinOptions: KotlinOptions(package: 'app.alextran.immich.background', includeErrorClass: false),
    arkTSOut: 'ohos/entry/src/main/ets/plugins/background/BackgroundWorkerLock.g.ets',
    arkTSOptions: ArkTSOptions(),
    dartOptions: DartOptions(),
    dartPackageName: 'immich_mobile',
  ),
)
@HostApi()
abstract class BackgroundWorkerLockApi {
  void lock();

  void unlock();
}
