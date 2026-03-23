import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/extensions/translate_extensions.dart';
import 'package:immich_mobile/models/cast/cast_manager_state.dart';
import 'package:immich_mobile/presentation/widgets/action_buttons/base_action_button.widget.dart';
import 'package:immich_mobile/providers/cast.provider.dart';

class CastActionButton extends ConsumerWidget {
  const CastActionButton({super.key, this.iconOnly = false, this.menuItem = false});

  final bool iconOnly;
  final bool menuItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cast = ref.watch(castProvider);

    return BaseActionButton(
      iconData: cast.isCasting ? Icons.cast_connected_rounded : Icons.cast_rounded,
      iconColor: cast.isCasting ? context.primaryColor : null,
      label: "cast".t(context: context),
      onPressed: () => ref.read(castProvider.notifier).connect(CastDestinationType.googleCast, null),
      iconOnly: iconOnly,
      menuItem: menuItem,
    );
  }
}
