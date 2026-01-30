import 'dart:async';
import 'dart:ffi';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    final bool isHdr = info['isHdr'] as bool? ?? false;
    final int? width = info['width'] as int?;
    final int? height = info['height'] as int?;
    final int? rowBytes = info['rowBytes'] as int?;
    if (width != null && height != null && rowBytes != null) {
      return switch (pointer) {
        int address => _fromDecodedPlatformImagePointer(address, width, height, rowBytes, isHdr),
        Uint8List data => _fromDecodedPlatformImage(data, width, height, rowBytes, isHdr),
        _ => null,
      };
    }

    final int length = info['length'] as int? ?? 0;
    return switch (pointer) {
      int address => _fromEncodedPlatformImagePointer(address, length),
      Uint8List data => _fromEncodedPlatformImage(data, length),
      _ => null,
    };
  }

  Future<ui.FrameInfo?> _fromEncodedPlatformImage(Uint8List data, int length) async {
    if (_isCancelled) {
      return null;
    }

    final int effectiveLength = length > 0 && length <= data.length ? length : data.length;
    final Uint8List view =
        effectiveLength == data.length ? data : Uint8List.view(data.buffer, data.offsetInBytes, effectiveLength);
    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(view);
    return _decodeEncodedBuffer(buffer);
  }

  Future<ui.FrameInfo?> _fromEncodedPlatformImagePointer(int address, int length) async {
    if (address == 0) {
      return null;
    }
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

    return _decodeEncodedBuffer(buffer);
  }

  Future<ui.FrameInfo?> _decodeEncodedBuffer(ui.ImmutableBuffer buffer) async {
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
    Uint8List data,
    int width,
    int height,
    int rowBytes,
    bool isHdr,
  ) async {
    if (_isCancelled) {
      return null;
    }

    final ui.ImmutableBuffer buffer = await ui.ImmutableBuffer.fromUint8List(data);
    final int effectiveRowBytes = rowBytes > 0 ? rowBytes : width * 4;
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
