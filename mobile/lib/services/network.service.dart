import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/repositories/network.repository.dart';
import 'package:immich_mobile/repositories/permission.repository.dart';

import 'package:flutter/foundation.dart';

final networkServiceProvider = Provider((ref) {
  return NetworkService(ref.watch(networkRepositoryProvider), ref.watch(permissionRepositoryProvider));
});

class NetworkService {
  final NetworkRepository _repository;
  final IPermissionRepository _permissionRepository;

  const NetworkService(this._repository, this._permissionRepository);

  Future<bool> getLocationWhenInUserPermission() {
    return _permissionRepository.hasLocationWhenInUsePermission();
  }

  Future<bool> requestLocationWhenInUsePermission() {
    return _permissionRepository.requestLocationWhenInUsePermission();
  }

  Future<bool> getLocationAlwaysPermission() {
    return _permissionRepository.hasLocationAlwaysPermission();
  }

  Future<bool> requestLocationAlwaysPermission() {
    return _permissionRepository.requestLocationAlwaysPermission();
  }

  Future<String?> getWifiName() async {
    if (defaultTargetPlatform == TargetPlatform.ohos) {
      return await _repository.getWifiName(); //ohos don't need request
    }

    final canRead = await getLocationWhenInUserPermission();
    if (!canRead) {
      return null;
    }

    return await _repository.getWifiName();
  }

  Future<bool> openSettings() {
    return _permissionRepository.openSettings();
  }
}
