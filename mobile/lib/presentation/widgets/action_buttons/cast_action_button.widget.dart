import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/base_action_button.widget.dart';
import 'package:immich_mobile/providers/cast.provider.dart';
import 'package:immich_mobile/widgets/asset_viewer/cast_dialog.dart';
import 'package:immich_mobile/presentation/widgets/asset_viewer/video_viewer.widget.dart';

class CastActionButton extends ConsumerWidget {
  const CastActionButton({super.key, required this.id, this.menuItem = true});

  final bool menuItem;
  final String id;

  handleCastAsset(id) {
    if (castController != null) {
      castController!.startCast(id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    //final isCasting = ref.watch(castProvider.select((c) => c.isCasting));

    return BaseActionButton(
      //iconData: isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
      iconData: Icons.cast_rounded,
      //iconColor: isCasting ? context.primaryColor : null, // null = default color
      iconColor: null, // null = default color
      label: "cast".t(context: context),
      onPressed: () {
        handleCastAsset(id);
      },
      menuItem: menuItem,
    );
  }
}
