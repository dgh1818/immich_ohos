import 'dart:async';
import 'dart:ffi';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:ffi/ffi.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';

part 'local_image_request.dart';
part 'remote_image_request.dart';
part 'thumbhash_image_request.dart';

abstract class ImageRequest {
  static int _nextRequestId = 0;

  final int requestId = _nextRequestId++;
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  ImageRequest();

  // OHOS fork (AI HDR): encoded-byte loads can be decoded through the
  // engine's SDR -> HLG conversion. Raw-pixel loads keep their native pixel
  // format and use the HDR descriptor only when the native side marks it.
  bool aiHdr = false;

  Future<ImageInfo?> load(ImageDecoderCallback decode, {double scale = 1.0});

  Future<ui.Codec?> loadCodec();

  void cancel() {
    if (_isCancelled) {
      return;
    }
    _isCancelled = true;
    return _onCancelled();
  }

  void _onCancelled();

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromEncodedPlatformImage(
    int address,
    int length, {
    ui.Size? decodeSize,
    bool aiHdr = false,
  }) async {
    final pointer = Pointer<Uint8>.fromAddress(address);
    if (_isCancelled) {
      malloc.free(pointer);
      return null;
    }

    final ui.ImmutableBuffer buffer;
    try {
      buffer = await ImmutableBuffer.fromUint8List(pointer.asTypedList(length));
    } finally {
      malloc.free(pointer);
    }

    if (_isCancelled) {
      buffer.dispose();
      return null;
    }

    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    buffer.dispose();
    if (_isCancelled) {
      descriptor.dispose();
      return null;
    }

    final target = _targetSize(descriptor.width, descriptor.height, decodeSize);
    final codec = aiHdr
        ? await descriptor.instantiateCodecWithDynamicRange(
            dynamicRangePolicy: ui.ImageDynamicRangePolicy.aiHdrAuto,
            targetWidth: target?.$1,
            targetHeight: target?.$2,
          )
        : await descriptor.instantiateCodec(targetWidth: target?.$1, targetHeight: target?.$2);
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    return (codec, descriptor);
  }

  Future<ui.FrameInfo?> _fromEncodedPlatformImage(
    int address,
    int length, {
    ui.Size? decodeSize,
    bool aiHdr = false,
  }) async {
    final result = await _codecFromEncodedPlatformImage(address, length, decodeSize: decodeSize, aiHdr: aiHdr);
    if (result == null) {
      return null;
    }

    final (codec, descriptor) = result;
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    final frame = await codec.getNextFrame();
    descriptor.dispose();
    codec.dispose();
    if (_isCancelled) {
      frame.image.dispose();
      return null;
    }

    return frame;
  }

  (int, int)? _targetSize(int width, int height, ui.Size? decodeSize) {
    if (width <= 0 || height <= 0 || decodeSize == null || decodeSize.width <= 0 || decodeSize.height <= 0) {
      return null;
    }

    final scale = math.max(decodeSize.width / width, decodeSize.height / height);
    if (scale >= 1) {
      return null;
    }

    return ((width * scale).ceil(), (height * scale).ceil());
  }

  Future<ui.FrameInfo?> _fromDecodedPlatformImage(
    int address,
    int width,
    int height,
    int rowBytes, [
    bool isHdr = false,
  ]) async {
    final pointer = Pointer<Uint8>.fromAddress(address);
    if (_isCancelled) {
      malloc.free(pointer);
      return null;
    }

    final size = rowBytes * height;
    final ui.ImmutableBuffer buffer;
    try {
      buffer = await ImmutableBuffer.fromUint8List(pointer.asTypedList(size));
    } finally {
      malloc.free(pointer);
    }

    if (_isCancelled) {
      buffer.dispose();
      return null;
    }

    final descriptor = ui.ImageDescriptor.raw(
      buffer,
      width: width,
      height: height,
      rowBytes: rowBytes,
      pixelFormat: isHdr ? ui.PixelFormat.rgba1010102 : ui.PixelFormat.rgba8888,
    );
    buffer.dispose();

    final codec = await descriptor.instantiateCodec();
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    final frame = await codec.getNextFrame();
    descriptor.dispose();
    codec.dispose();
    if (_isCancelled) {
      frame.image.dispose();
      return null;
    }

    return frame;
  }
}
