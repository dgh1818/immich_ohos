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

  // ignore: unused-code
  bool get isCancelled => _isCancelled;

  ImageRequest();

  // OHOS fork: an encoded request may explicitly preserve the source dynamic
  // range or request the SDR -> HLG AI HDR conversion. Raw-pixel loads keep
  // their native pixel format and use the HDR descriptor only when the native
  // side marks it.
  ui.ImageDynamicRangePolicy? dynamicRangePolicy;

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

  // OHOS remote currently hands off encoded bytes. Other native producers
  // can also return decoded pixels, including JPEG XL on Android and iOS.
  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromResponse(Map<String, Object>? info, {ui.Size? decodeSize}) async {
    switch (info) {
      case {'pointer': final int pointer, 'length': final int length} when pointer != 0 && length > 0:
        return _codecFromEncodedPlatformImage(
          pointer,
          length,
          decodeSize: decodeSize,
          dynamicRangePolicy: dynamicRangePolicy,
        );
      case {
            'pointer': final int pointer,
            'width': final int width,
            'height': final int height,
            'rowBytes': final int rowBytes,
          }
          when pointer != 0 && width > 0 && height > 0 && rowBytes >= width * 4:
        return _codecFromDecodedPlatformImage(pointer, width, height, rowBytes, isHdr: info['isHdr'] == true);
      case {'pointer': final int pointer} when pointer != 0:
        malloc.free(Pointer<Uint8>.fromAddress(pointer));
        throw const FormatException('Invalid native image buffer metadata');
      default:
        // OHOS cancellation can reply with an empty map.
        return null;
    }
  }

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromEncodedPlatformImage(
    int address,
    int length, {
    ui.Size? decodeSize,
    ui.ImageDynamicRangePolicy? dynamicRangePolicy,
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

    final ui.ImageDescriptor descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
    } finally {
      buffer.dispose();
    }
    if (_isCancelled) {
      descriptor.dispose();
      return null;
    }

    final target = _targetSize(descriptor.width, descriptor.height, decodeSize);
    final ui.Codec codec;
    try {
      codec = dynamicRangePolicy == null
          ? await descriptor.instantiateCodec(targetWidth: target?.$1, targetHeight: target?.$2)
          : await _instantiateHdrCodec(descriptor, dynamicRangePolicy, target);
    } catch (_) {
      descriptor.dispose();
      rethrow;
    }
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    return (codec, descriptor);
  }

  // Keep the OHOS-only engine call outside the standard decode path.
  Future<ui.Codec> _instantiateHdrCodec(
    ui.ImageDescriptor descriptor,
    ui.ImageDynamicRangePolicy policy,
    (int, int)? target,
  ) => descriptor.instantiateCodecWithDynamicRange(
    dynamicRangePolicy: policy,
    targetWidth: target?.$1,
    targetHeight: target?.$2,
  );

  Future<ui.FrameInfo?> _firstFrame((ui.Codec, ui.ImageDescriptor)? result) async {
    if (result == null) {
      return null;
    }

    final (codec, descriptor) = result;
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    final ui.FrameInfo frame;
    try {
      frame = await codec.getNextFrame();
    } finally {
      descriptor.dispose();
      codec.dispose();
    }
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

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromDecodedPlatformImage(
    int address,
    int width,
    int height,
    int rowBytes, {
    bool isHdr = false,
  }) async {
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

    final ui.ImageDescriptor descriptor;
    try {
      descriptor = ui.ImageDescriptor.raw(
        buffer,
        width: width,
        height: height,
        rowBytes: rowBytes,
        pixelFormat: isHdr ? ui.PixelFormat.rgba1010102 : ui.PixelFormat.rgba8888,
      );
    } finally {
      buffer.dispose();
    }

    final ui.Codec codec;
    try {
      codec = await descriptor.instantiateCodec();
    } catch (_) {
      descriptor.dispose();
      rethrow;
    }
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    return (codec, descriptor);
  }
}

// Raw and single-frame codecs can defer decoding until getNextFrame().
class _DescriptorBackedCodec implements ui.Codec {
  final ui.Codec _codec;
  final ui.ImageDescriptor _descriptor;

  _DescriptorBackedCodec(this._codec, this._descriptor);

  @override
  int get frameCount => _codec.frameCount;

  @override
  int get repetitionCount => _codec.repetitionCount;

  @override
  Future<ui.FrameInfo> getNextFrame() => _codec.getNextFrame();

  @override
  void dispose() {
    try {
      _codec.dispose();
    } finally {
      _descriptor.dispose();
    }
  }
}
