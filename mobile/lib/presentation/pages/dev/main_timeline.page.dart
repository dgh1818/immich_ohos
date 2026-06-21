import 'dart:io';

import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/memory/memory_lane.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';
import 'package:immich_mobile/services/foreground_upload.service.dart';
import 'package:immich_mobile/widgets/common/immich_sliver_app_bar.dart';
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

@RoutePage()
class MainTimelinePage extends ConsumerWidget {
  const MainTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMemories = ref.watch(driftMemoryFutureProvider.select((state) => state.value?.isNotEmpty ?? false));
    const actionTop = 30.0;
    const actionButtonSize = 48.0;
    const uploadIconSize = 30.0;

    Future<void> pickUploadImage() async {
      final List<XFile> medias = await ImagePicker().pickMultipleMedia();
      if (medias.isEmpty) {
        return;
      }

      final uploadService = ref.read(foregroundUploadServiceProvider);
      int successCount = 0;
      int errorCount = 0;

      await uploadService.uploadShareIntent(
        medias.map((media) => File(media.path)).toList(),
        mergeOhosLivePhotos: true,
        onSuccess: (_, __) => successCount++,
        onError: (_, error) {
          errorCount++;
          debugPrint('上传失败: $error');
        },
      );

      if (!context.mounted) {
        return;
      }

      if (successCount > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅$successCount 个照片/视频上传完成'), duration: const Duration(seconds: 2)));
      }

      if (errorCount > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$errorCount 个照片/视频上传失败'), backgroundColor: Colors.redAccent));
      }
    }

    return Stack(
      children: [
        Positioned.fill(
          child: Timeline(
            topSliverWidget: const SliverToBoxAdapter(child: DriftMemoryLane()),
            topSliverWidgetHeight: hasMemories ? 200 : 0,
            showStorageIndicator: true,
          ),
        ),
        Positioned(
          top: actionTop,
          right: 110,
          child: SizedBox(
            width: actionButtonSize,
            height: actionButtonSize,
            child: InkWell(
              onTap: pickUploadImage,
              borderRadius: BorderRadius.circular(12),
              child: Center(child: SvgPicture.asset('assets/HMOS_arrowshape_up.svg', height: uploadIconSize)),
            ),
          ),
        ),
        const Positioned(top: actionTop, right: 20, child: ProfileIndicator()),
        const Positioned(top: actionTop, right: 70, child: BackupIndicator()),
        const Positioned(top: actionTop, left: 20, child: SyncStatusIndicator()),
      ],
    );
  }
}
