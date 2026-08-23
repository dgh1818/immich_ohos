import 'dart:io' show Platform;

import 'package:package_info_plus/package_info_plus.dart';

Future<String> getUserAgentString() async {
  final packageInfo = await PackageInfo.fromPlatform();
  String platform;
  if (Platform.isAndroid) {
    platform = 'android';
  } else if (Platform.isIOS) {
    platform = 'ios';
  } else if (Platform.isOhos) {
    platform = 'ohos';
  } else {
    platform = 'unknown';
  }
  return 'immich-$platform/${packageInfo.version}';
}
