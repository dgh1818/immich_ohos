import 'package:auto_route/auto_route.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:immich_mobile/domain/models/feature_message.model.dart';
import 'package:immich_mobile/extensions/build_context_extensions.dart';
import 'package:immich_mobile/generated/translations.g.dart';
import 'package:immich_mobile/presentation/widgets/feature_message/feature_message_placeholder.widget.dart';

@RoutePage()
class WhatsNewPage extends StatelessWidget {
  const WhatsNewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final highlights = visibleFeatureMessageHighlights;
    final scheme = context.colorScheme;

    return Scaffold(
      appBar: AppBar(centerTitle: false, title: Text(context.t.whats_new)),
      body: ListView.builder(
        padding: const EdgeInsets.only(top: 16, bottom: 64),
        itemCount: highlights.length + 1, // +1 for changelog
        itemBuilder: (_, index) {
          if (index < highlights.length) {
            return _HighlightCard(highlight: highlights[index]);
          }
          // Changelog section
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Divider(indent: 16, endIndent: 16),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    '更新日志',
                    style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: const BorderRadius.all(Radius.circular(12)),
                    ),
                    child: Text(
                      context.t.changelog_text,
                      style: context.textTheme.bodySmall?.copyWith(
                        color: context.colorScheme.onSurfaceVariant,
                        height: 1.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HighlightCard extends StatelessWidget {
  final FeatureHighlight highlight;

  const _HighlightCard({required this.highlight});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(18)),
              child: SizedBox(
                width: double.infinity,
                height: 256,
                child: highlight.image == null
                    ? const FeatureMessagePlaceholder()
                    : Image.asset(
                        highlight.image!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, _, __) => const FeatureMessagePlaceholder(),
                      ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(highlight.titleKey.tr(), style: context.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(
            highlight.bodyKey.tr(),
            style: context.textTheme.bodyMedium?.copyWith(color: context.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
