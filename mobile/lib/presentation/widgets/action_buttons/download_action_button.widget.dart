import 'package:immich_mobile/constants/enums.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/domain/utils/background_sync.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/base_action_button.widget.dart';
import 'package:immich_mobile/providers/background_sync.provider.dart';
import 'package:immich_mobile/providers/infrastructure/action.provider.dart';
import 'package:immich_mobile/providers/timeline/multiselect.provider.dart';

class DownloadActionButton extends ConsumerWidget {
  final ActionSource source;
  final bool iconOnly;
  final bool menuItem;
  const DownloadActionButton({super.key, required this.source, this.iconOnly = false, this.menuItem = false});

  void _onTap(
    ActionNotifier actionNotifier,
    MultiSelectNotifier multiSelectNotifier,
    BackgroundSyncManager backgroundSyncManager,
  ) async {
    try {
      await actionNotifier.downloadAll(source);

      Future.delayed(const Duration(seconds: 1), () async {
        await backgroundSyncManager.syncLocal();
        await backgroundSyncManager.hashAssets();
      });
    } finally {
      multiSelectNotifier.reset();
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final backgroundManager = ref.watch(backgroundSyncProvider);
    final actionNotifier = ref.read(actionProvider.notifier);
    final multiSelectNotifier = ref.read(multiSelectProvider.notifier);

    return BaseActionButton(
      iconData: Icons.download,
      maxWidth: 95,
      label: "download".t(context: context),
      iconOnly: iconOnly,
      menuItem: menuItem,
      onPressed: () => _onTap(actionNotifier, multiSelectNotifier, backgroundManager),
    );
  }
}
