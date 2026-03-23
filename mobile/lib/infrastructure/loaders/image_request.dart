import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:ffi/ffi.dart';
import 'package:immich_mobile/domain/models/asset/base_asset.model.dart';
import 'package:immich_mobile/providers/infrastructure/platform.provider.dart';

part 'local_image_request.dart';
part 'thumbhash_image_request.dart';
part 'remote_image_request.dart';

abstract class ImageRequest {
  static int _nextRequestId = 0;

  final int requestId = _nextRequestId++;
  bool _isCancelled = false;

  get isCancelled => _isCancelled;

  ImageRequest();

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

  Future<ui.FrameInfo?> _fromPlatformImage(Map<String, Object> info) async {
    final Object? pointer = info['pointer'];
    if (pointer == null) {
      return null;
    }

    final length = info['length'] as int?;
    if (length != null) {
      return _fromEncodedPlatformImage(pointer, length);
    }

    final width = info['width'] as int?;
    final height = info['height'] as int?;
    final rowBytes = info['rowBytes'] as int?;
    if (width == null || height == null || rowBytes == null) {
      return null;
    }

    final isHdr = info['isHdr'] as bool? ?? false;
    return _fromDecodedPlatformImage(
      pointer,
      width,
      height,
      rowBytes,
      isHdr,
    );
  }

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromEncodedPlatformImage(
    Object image,
    int length,
  ) async {
    return switch (image) {
      int address => _codecFromEncodedPlatformImagePointer(address, length),
      Uint8List data => _codecFromEncodedPlatformImageData(data, length),
      _ => null,
    };
  }

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromEncodedPlatformImageData(
    Uint8List data,
    int length,
  ) async {
    if (_isCancelled) {
      return null;
    }

    final int effectiveLength = length > 0 && length <= data.length ? length : data.length;
    final Uint8List view =
        effectiveLength == data.length ? data : Uint8List.view(data.buffer, data.offsetInBytes, effectiveLength);

    final buffer = await ui.ImmutableBuffer.fromUint8List(view);
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

    final codec = await descriptor.instantiateCodec();
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    return (codec, descriptor);
  }

  Future<(ui.Codec, ui.ImageDescriptor)?> _codecFromEncodedPlatformImagePointer(int address, int length) async {
    if (address == 0 || length <= 0) {
      if (address != 0) {
        malloc.free(Pointer<Uint8>.fromAddress(address));
      }
      return null;
    }

    final pointer = Pointer<Uint8>.fromAddress(address);
    if (_isCancelled) {
      malloc.free(pointer);
      return null;
    }

    final ui.ImmutableBuffer buffer;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(pointer.asTypedList(length));
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

    final codec = await descriptor.instantiateCodec();
    if (_isCancelled) {
      descriptor.dispose();
      codec.dispose();
      return null;
    }

    return (codec, descriptor);
  }

  Future<ui.FrameInfo?> _fromEncodedPlatformImage(Object image, int length) async {
    final result = await _codecFromEncodedPlatformImage(image, length);
    if (result == null) return null;

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

  Future<ui.FrameInfo?> _fromDecodedPlatformImage(
    Object image,
    int width,
    int height,
    int rowBytes,
    bool isHdr,
  ) async {
    return switch (image) {
      int address => _fromDecodedPlatformImagePointer(address, width, height, rowBytes, isHdr),
      Uint8List data => _fromDecodedPlatformImageData(data, width, height, rowBytes, isHdr),
      _ => null,
    };
  }

  Future<ui.FrameInfo?> _fromDecodedPlatformImageData(
    Uint8List data,
    int width,
    int height,
    int rowBytes,
    bool isHdr,
  ) async {
    if (_isCancelled) {
      return null;
    }

    final buffer = await ui.ImmutableBuffer.fromUint8List(data);
    final effectiveRowBytes = rowBytes > 0 ? rowBytes : width * 4;
    return _decodeRawBuffer(buffer, width, height, effectiveRowBytes, isHdr);
  }

  Future<ui.FrameInfo?> _fromDecodedPlatformImagePointer(
    int address,
    int width,
    int height,
    int rowBytes,
    bool isHdr,
  ) async {
    if (address == 0) {
      return null;
    }

    final int effectiveRowBytes = rowBytes > 0 ? rowBytes : width * 4;
    final length = effectiveRowBytes * height;
    if (length <= 0) {
      malloc.free(Pointer<Uint8>.fromAddress(address));
      return null;
    }

    final pointer = Pointer<Uint8>.fromAddress(address);
    if (_isCancelled) {
      malloc.free(pointer);
      return null;
    }

    final ui.ImmutableBuffer buffer;
    try {
      buffer = await ui.ImmutableBuffer.fromUint8List(pointer.asTypedList(length));
    } finally {
      malloc.free(pointer);
    }

    return _decodeRawBuffer(buffer, width, height, effectiveRowBytes, isHdr);
  }

  Future<ui.FrameInfo?> _decodeRawBuffer(
    ui.ImmutableBuffer buffer,
    int width,
    int height,
    int rowBytes,
    bool isHdr,
  ) async {
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
