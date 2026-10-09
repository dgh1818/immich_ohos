// ignore_for_file: use-ref-and-state-synchronously

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/domain/services/setting.service.dart';
import 'package:immich_mobile/providers/infrastructure/store.provider.dart';

class SettingsNotifier extends Notifier<SettingsService> {
  @override
  SettingsService build() => SettingsService(storeService: ref.read(storeServiceProvider));

  T get<T>(Setting<T> setting) => state.get(setting);

  Future<void> set<T>(Setting<T> setting, T value) async {
    final storeService = ref.read(storeServiceProvider);
    await storeService.put(setting.storeKey, value);
    state = SettingsService(storeService: storeService);
  }
}

final settingsProvider = NotifierProvider<SettingsNotifier, SettingsService>(SettingsNotifier.new);
