// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_viewer_controller_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$videoViewerControllerHash() =>
    r'2941bc385ff9323a59e992347a33a815e95fb491';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [videoViewerController].
@ProviderFor(videoViewerController)
const videoViewerControllerProvider = VideoViewerControllerFamily();

/// See also [videoViewerController].
class VideoViewerControllerFamily
    extends Family<AsyncValue<VideoPlayerController>> {
  /// See also [videoViewerController].
  const VideoViewerControllerFamily();

  /// See also [videoViewerController].
  VideoViewerControllerProvider call({required BaseAsset asset}) {
    return VideoViewerControllerProvider(asset: asset);
  }

  @override
  VideoViewerControllerProvider getProviderOverride(
    covariant VideoViewerControllerProvider provider,
  ) {
    return call(asset: provider.asset);
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'videoViewerControllerProvider';
}

/// See also [videoViewerController].
class VideoViewerControllerProvider
    extends AutoDisposeFutureProvider<VideoPlayerController> {
  /// See also [videoViewerController].
  VideoViewerControllerProvider({required BaseAsset asset})
    : this._internal(
        (ref) => videoViewerController(
          ref as VideoViewerControllerRef,
          asset: asset,
        ),
        from: videoViewerControllerProvider,
        name: r'videoViewerControllerProvider',
        debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
            ? null
            : _$videoViewerControllerHash,
        dependencies: VideoViewerControllerFamily._dependencies,
        allTransitiveDependencies:
            VideoViewerControllerFamily._allTransitiveDependencies,
        asset: asset,
      );

  VideoViewerControllerProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.asset,
  }) : super.internal();

  final BaseAsset asset;

  @override
  Override overrideWith(
    FutureOr<VideoPlayerController> Function(VideoViewerControllerRef provider)
    create,
  ) {
    return ProviderOverride(
      origin: this,
      override: VideoViewerControllerProvider._internal(
        (ref) => create(ref as VideoViewerControllerRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        asset: asset,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<VideoPlayerController> createElement() {
    return _VideoViewerControllerProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is VideoViewerControllerProvider && other.asset == asset;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, asset.hashCode);

    return _SystemHash.finish(hash);
  }
}

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
mixin VideoViewerControllerRef
    on AutoDisposeFutureProviderRef<VideoPlayerController> {
  /// The parameter `asset` of this provider.
  BaseAsset get asset;
}

class _VideoViewerControllerProviderElement
    extends AutoDisposeFutureProviderElement<VideoPlayerController>
    with VideoViewerControllerRef {
  _VideoViewerControllerProviderElement(super.provider);

  @override
  BaseAsset get asset => (origin as VideoViewerControllerProvider).asset;
}

// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
