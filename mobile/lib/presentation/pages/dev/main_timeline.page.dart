import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/presentation/widgets/memory/memory_lane.widget.dart';
import 'package:immich_mobile/presentation/widgets/timeline/timeline.widget.dart';
import 'package:immich_mobile/providers/infrastructure/memory.provider.dart';

import 'package:immich_mobile/services/backup.service.dart';
import 'package:immich_mobile/widgets/common/immich_sliver_app_bar.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_svg/svg.dart';
import 'package:image_picker/image_picker.dart';

@RoutePage()
class MainTimelinePage extends ConsumerWidget {
  const MainTimelinePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasMemories = ref.watch(driftMemoryFutureProvider.select((state) => state.value?.isNotEmpty ?? false));

    Future<void> pickUploadImage() async {
      final List<XFile> medias = await ImagePicker().pickMultipleMedia();
      if (medias.isEmpty) return;

      final backupService = ref.read(backupServiceProvider);
      int successCount = 0;

      for (int i = 0; i < medias.length; i++) {
        final current = medias[i];
        final next = i + 1 < medias.length ? medias[i + 1] : null;
        final sameStem =
            next != null && p.basenameWithoutExtension(current.name) == p.basenameWithoutExtension(next.name);

        try {
          if (sameStem && next != null) {
            await backupService.uploadImageDirectly(next, current);
            successCount += 2;
            i++;
          } else {
            await backupService.uploadImageDirectly(current, null);
            successCount++;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('“${current.name}” 上传成功: $successCount / ${medias.length}'),
              duration: const Duration(seconds: 1),
            ),
          );
        } catch (e) {
          debugPrint('上传失败: ${current.name} — $e');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('“${current.name}” 上传失败: ${e.toString()}'),
              backgroundColor: Colors.redAccent,
              duration: const Duration(seconds: 10),
            ),
          );
        }
      }

      if (successCount > 0) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('✅$successCount 个照片/视频上传完成'), duration: const Duration(seconds: 2)));
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
          top: 25,
          right: 110,
          child: InkWell(
            onTap: pickUploadImage,
            borderRadius: BorderRadius.circular(12),
            child: SvgPicture.asset('assets/HMOS_arrowshape_up.svg', height: 40),
          ),
        ),
        const Positioned(top: 30, right: 20, child: ProfileIndicator()),
        const Positioned(top: 30, right: 70, child: BackupIndicator()),
        const Positioned(top: 35, left: 20, child: SyncStatusIndicator()),
      ],
    );
  }
}
