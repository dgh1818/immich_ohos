import 'package:flutter/material.dart';

class CustomTransitionsBuilders {
  const CustomTransitionsBuilders._();

  static const ZoomPageTransitionsBuilder _zoomBuilder = ZoomPageTransitionsBuilder(
    allowSnapshotting: false,
    allowEnterRouteSnapshotting: false,
  );

  static const RouteTransitionsBuilder zoomedPage = _zoomedPage;

  static Widget _zoomedPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 用当前真实的 PageRoute
    final route = ModalRoute.of(context);

    if (route is PageRoute) {
      return _zoomBuilder.buildTransitions(route, context, animation, secondaryAnimation, child);
    }

    // 兜底：拿不到 PageRoute 时，简单做个缩放+渐隐
    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.5, end: 1.0).chain(CurveTween(curve: Curves.easeOutCubic)).animate(animation),
        child: child,
      ),
    );
  }
}
