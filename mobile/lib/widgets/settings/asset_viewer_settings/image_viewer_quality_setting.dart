import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/models/setting.model.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/providers/app_settings.provider.dart';
import 'package:immich_mobile/providers/infrastructure/setting.provider.dart' as store_settings;
import 'package:immich_mobile/providers/infrastructure/settings.provider.dart';
import 'package:immich_mobile/widgets/settings/setting_group_title.dart';
import 'package:immich_mobile/widgets/settings/settings_switch_list_tile.dart';

class ImageViewerQualitySetting extends HookConsumerWidget {
  const ImageViewerQualitySetting({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOriginal = useState(ref.watch(appConfigProvider).image.loadOriginal);
    useValueChanged<bool, void>(isOriginal.value, (_, _) {
      unawaited(ref.read(settingsProvider).write(.imageLoadOriginal, isOriginal.value));
    });
    final imageHdr = useState(ref.read(store_settings.settingsProvider.notifier).get(Setting.imageHdr));
    useValueChanged<bool, void>(imageHdr.value, (_, __) {
      unawaited(ref.read(store_settings.settingsProvider.notifier).set(Setting.imageHdr, imageHdr.value));
    });
    final aiHdr = useState(ref.read(store_settings.settingsProvider.notifier).get(Setting.aiHdr));
    useValueChanged<bool, void>(aiHdr.value, (_, __) {
      unawaited(ref.read(store_settings.settingsProvider.notifier).set(Setting.aiHdr, aiHdr.value));
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingGroupTitle(
          title: context.t.photos,
          icon: Icons.image_outlined,
          subtitle: context.t.setting_image_viewer_help,
        ),
        SettingsSwitchListTile(
          valueNotifier: isOriginal,
          title: context.t.setting_image_viewer_original_title,
          subtitle: context.t.setting_image_viewer_original_subtitle,
          onChanged: (_) => ref.invalidate(appSettingsServiceProvider),
        ),
        SettingsSwitchListTile(valueNotifier: imageHdr, title: "图片 HDR", subtitle: "在支持 HDR 的设备上以 HDR 方式显示图片"),
        SettingsSwitchListTile(valueNotifier: aiHdr, title: "图片 AI HDR", subtitle: "将 SDR 照片经 VPE 转换为 HLG 显示"),
      ],
    );
  }
}
