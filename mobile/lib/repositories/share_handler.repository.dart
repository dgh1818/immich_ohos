import 'dart:async';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:immich_mobile/models/upload/share_intent_attachment.model.dart';
import 'package:path/path.dart' as p;
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

final shareHandlerRepositoryProvider = Provider((ref) => ShareHandlerRepository());

class ShareHandlerRepository {
  ShareHandlerRepository();

  void Function(List<ShareIntentAttachment> attachments)? onSharedMedia;
  StreamSubscription<List<SharedMediaFile>>? _mediaSub;
  Timer? _mediaDebounce;
  final List<ShareIntentAttachment> _pendingMedia = [];

  Future<void> init() async {
    final handler = ReceiveSharingIntent.instance;
    final media = await handler.getInitialMedia();
    if (media.isNotEmpty) {
      onSharedMedia?.call(_buildPayload(media));
      await handler.reset();
    }

    await _mediaSub?.cancel();
    _mediaSub = handler.getMediaStream().listen((media) {
      if (media.isEmpty) {
        return;
      }

      final payload = _buildPayload(media);
      if (payload.isEmpty) {
        return;
      }

      _mergePending(payload);
      _mediaDebounce?.cancel();
      _mediaDebounce = Timer(const Duration(milliseconds: 250), _flushPendingMedia);
    });
  }

  Future<void> dispose() async {
    await _mediaSub?.cancel();
    _mediaSub = null;
    _mediaDebounce?.cancel();
    _mediaDebounce = null;
  }

  void _mergePending(List<ShareIntentAttachment> payload) {
    for (final attachment in payload) {
      if (!_pendingMedia.contains(attachment)) {
        _pendingMedia.add(attachment);
      }
    }
  }

  void _flushPendingMedia() {
    if (_pendingMedia.isEmpty) {
      return;
    }

    onSharedMedia?.call(List.unmodifiable(_pendingMedia));
    _pendingMedia.clear();
  }

  List<ShareIntentAttachment> _buildPayload(List<SharedMediaFile> attachments) {
    final payload = <ShareIntentAttachment>[];

    for (final attachment in attachments) {
      final path = attachment.uri;
      if (path == null || path.isEmpty) {
        continue;
      }

      final type = _resolveType(attachment, path);
      if (type == null) {
        continue;
      }

      payload.add(
        ShareIntentAttachment(
          path: path,
          type: type,
          status: UploadStatus.enqueued,
          uploadProgress: 0.0,
          fileLength: 0,
        ),
      );
    }

    return payload;
  }

  ShareIntentAttachmentType? _resolveType(SharedMediaFile attachment, String path) {
    final mime = attachment.mimeType?.toLowerCase();
    if (attachment.type == SharedMediaType.image || (mime?.startsWith('image/') ?? false)) {
      return ShareIntentAttachmentType.image;
    }
    if (attachment.type == SharedMediaType.video || (mime?.startsWith('video/') ?? false)) {
      return ShareIntentAttachmentType.video;
    }

    final ext = p.extension(path).toLowerCase();
    if (_imageExtensions.contains(ext)) {
      return ShareIntentAttachmentType.image;
    }
    if (_videoExtensions.contains(ext)) {
      return ShareIntentAttachmentType.video;
    }

    return null;
  }
}

const _imageExtensions = {'.jpg', '.jpeg', '.png', '.gif', '.webp', '.heic', '.heif', '.bmp', '.tif', '.tiff'};

const _videoExtensions = {'.mp4', '.mov', '.mkv', '.avi', '.webm', '.3gp', '.m4v', '.ts'};
