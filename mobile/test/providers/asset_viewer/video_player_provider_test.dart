import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/providers/asset_viewer/video_player_provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:native_video_player/native_video_player.dart';

class MockNativeVideoPlayerController extends Mock implements NativeVideoPlayerController {}

class MockPlaybackInfo extends Mock implements PlaybackInfo {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockNativeVideoPlayerController controller;
  late MockPlaybackInfo playbackInfo;
  late VideoPlayerNotifier notifier;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.ohos;
    controller = MockNativeVideoPlayerController();
    playbackInfo = MockPlaybackInfo();
    notifier = VideoPlayerNotifier()..attachController(controller);

    when(() => controller.playbackInfo).thenReturn(playbackInfo);
    when(() => controller.videoInfo).thenReturn(VideoInfo.fromJson({'width': 1920, 'height': 1080, 'duration': 60000}));
    when(() => playbackInfo.status).thenReturn(PlaybackStatus.playing);
    when(() => playbackInfo.position).thenReturn(0);
    when(() => controller.play()).thenAnswer((_) async {});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('seek suspends stall detection until native seek completes', () {
    fakeAsync((async) {
      final seek = Completer<void>();
      when(() => controller.seekTo(any())).thenAnswer((_) => seek.future);
      notifier.onNativePlaybackReady();
      unawaited(notifier.play());
      async.flushMicrotasks();

      async.elapse(const Duration(seconds: 2));
      notifier.seekTo(const Duration(seconds: 30));
      async.elapse(const Duration(milliseconds: 150));
      async.elapse(const Duration(seconds: 4));
      expect(notifier.state.status, VideoPlaybackStatus.playing);

      seek.complete();
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 2));
      expect(notifier.state.status, VideoPlaybackStatus.playing);
      async.elapse(const Duration(seconds: 1));
      expect(notifier.state.status, VideoPlaybackStatus.buffering);

      when(() => playbackInfo.position).thenReturn(31000);
      notifier.onNativePositionChanged();
      expect(notifier.state.status, VideoPlaybackStatus.playing);
      async.elapse(const Duration(seconds: 3));
      expect(notifier.state.status, VideoPlaybackStatus.buffering);
    });
  });

  test('release waits for hold pause and pending seek before playback', () {
    fakeAsync((async) {
      final pause = Completer<void>();
      final seek = Completer<void>();
      when(() => controller.pause()).thenAnswer((_) => pause.future);
      when(() => controller.seekTo(any())).thenAnswer((_) => seek.future);
      notifier.onNativePlaybackReady();

      notifier.hold();
      notifier.seekTo(const Duration(seconds: 30));
      notifier.release();
      verifyNever(() => controller.play());

      pause.complete();
      async.flushMicrotasks();
      verify(() => controller.seekTo(30000)).called(1);
      verifyNever(() => controller.play());

      seek.complete();
      async.flushMicrotasks();
      verify(() => controller.play()).called(1);
    });
  });

  test('scrubbing updates progress but sends only the final seek on release', () {
    fakeAsync((async) {
      final seek = Completer<void>();
      when(() => controller.pause()).thenAnswer((_) async {});
      when(() => controller.seekTo(any())).thenAnswer((_) => seek.future);
      notifier.onNativePlaybackReady();

      notifier.beginScrubbing();
      notifier.hold();
      notifier.seekTo(const Duration(seconds: 10));
      notifier.seekTo(const Duration(seconds: 20));
      notifier.seekTo(const Duration(seconds: 30));
      async.elapse(const Duration(seconds: 6));
      expect(notifier.state.position, const Duration(seconds: 30));
      verifyNever(() => controller.seekTo(any()));

      notifier.endScrubbing();
      notifier.release();
      async.flushMicrotasks();
      verify(() => controller.seekTo(30000)).called(1);
      verifyNever(() => controller.play());

      seek.complete();
      async.flushMicrotasks();
      verify(() => controller.play()).called(1);
    });
  });

  test('scrubbing a paused video still seeks without resuming playback', () {
    fakeAsync((async) {
      when(() => playbackInfo.status).thenReturn(PlaybackStatus.paused);
      when(() => controller.pause()).thenAnswer((_) async {});
      when(() => controller.seekTo(any())).thenAnswer((_) async {});
      notifier.onNativePlaybackReady();

      notifier.beginScrubbing();
      notifier.hold();
      notifier.seekTo(const Duration(seconds: 30));
      notifier.endScrubbing();
      notifier.release();
      async.flushMicrotasks();

      verify(() => controller.seekTo(30000)).called(1);
      verifyNever(() => controller.play());
    });
  });

  test('stale native positions do not move the slider during scrubbing', () {
    notifier.onNativePlaybackReady();
    notifier.beginScrubbing();
    notifier.seekTo(const Duration(seconds: 30));
    when(() => playbackInfo.position).thenReturn(1000);
    notifier.onNativePositionChanged();

    expect(notifier.state.position, const Duration(seconds: 30));
  });

  test('a playing seek ignores old positions until the native seek completes', () {
    fakeAsync((async) {
      final seek = Completer<void>();
      when(() => controller.seekTo(any())).thenAnswer((_) => seek.future);
      notifier.onNativePlaybackReady();

      notifier.beginScrubbing();
      notifier.seekTo(const Duration(seconds: 30));
      notifier.endScrubbing();
      when(() => playbackInfo.position).thenReturn(1000);
      notifier.onNativePositionChanged();
      expect(notifier.state.position, const Duration(seconds: 30));

      seek.complete();
      async.flushMicrotasks();
      when(() => playbackInfo.position).thenReturn(30000);
      notifier.onNativePositionChanged();
      expect(notifier.state.position, const Duration(seconds: 30));
      verifyNever(() => controller.pause());
      verifyNever(() => controller.play());
    });
  });

  test('reset during the final native seek does not resume playback', () {
    fakeAsync((async) {
      final seek = Completer<void>();
      when(() => controller.pause()).thenAnswer((_) async {});
      when(() => controller.seekTo(any())).thenAnswer((_) => seek.future);
      notifier.onNativePlaybackReady();

      notifier.beginScrubbing();
      notifier.hold();
      notifier.seekTo(const Duration(seconds: 30));
      notifier.endScrubbing();
      notifier.release();
      async.flushMicrotasks();
      verify(() => controller.seekTo(30000)).called(1);

      notifier.reset();
      seek.complete();
      async.flushMicrotasks();

      verifyNever(() => controller.play());
      expect(notifier.state.status, VideoPlaybackStatus.paused);
    });
  });

  test('reset while release is waiting for pause does not restart playback', () {
    fakeAsync((async) {
      final pause = Completer<void>();
      when(() => controller.pause()).thenAnswer((_) => pause.future);
      notifier.onNativePlaybackReady();

      notifier.hold();
      notifier.release();
      notifier.reset();
      pause.complete();
      async.flushMicrotasks();

      verifyNever(() => controller.play());
      expect(notifier.state.status, VideoPlaybackStatus.paused);
    });
  });
}
