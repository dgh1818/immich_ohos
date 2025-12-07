import 'dart:async';

import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class HuaweiCast {
  static const MethodChannel _channel = MethodChannel('huawei_cast');
  final VideoPlayerController controller;

  HuaweiCast(this.controller) {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'play':
        await controller.play();
        break;
      case 'pause':
        await controller.pause();
        break;
      case 'next':
        // 这里根据你的逻辑跳转下一视频
        break;
      case 'previous':
        // 跳转上一视频
        break;
      case 'seekTo':
        final position = Duration(milliseconds: call.arguments['position']);
        await controller.seekTo(position);
        break;
      default:
        print('Unknown native call: ${call.method}');
    }
  }

  FutureOr<dynamic> setMetadata(String contentUrl, String mediaImage, String title, int duration) async {
    final result = await _channel.invokeMethod('setMetadata', <String, dynamic>{
      'contentUrl': contentUrl,
      'mediaImage': mediaImage,
      'title': title,
      'duration': duration,
    });
    return result;
  }

  FutureOr<dynamic> startCast(String assetId) async {
    final result = await _channel.invokeMethod('startCast', <String, dynamic>{'assetId': assetId});
    return result;
  }

  FutureOr<dynamic> setCurrentPosition(int position, bool isPlaying) async {
    final result = await _channel.invokeMethod('setCurrentPosition', <String, dynamic>{
      'position': position,
      'isPlaying': isPlaying,
    });
    return result;
  }

  FutureOr<dynamic> clearSession() async {
    final result = await _channel.invokeMethod('clearSession');
    return result;
  }
}
