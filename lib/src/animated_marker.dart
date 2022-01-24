
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import '/src/size_utils.dart';

class AnimatedMarker {
  static Widget _defaultAnimateBuilder(BuildContext context, Animation<double> animation, Widget child) {
    return Transform.scale(
      scale: animation.value,
      child: child
    );
  }

  final LatLng point;

  final Widget child;

  final Key key;

  final Size size;

  final SizeUnit sizeUnit;

  final Alignment anchor;

  // If false the marker will be counter rotated on map rotation, else it will rotate with the map.

  final bool rotate;

  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget child
  ) animateInBuilder;
  final Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget child
  ) animateOutBuilder;

  final Curve animateInCurve;
  final Curve animateOutCurve;

  final Duration animateInDuration;
  final Duration animateOutDuration;

  final Duration animateInDelay;
  final Duration animateOutDelay;

  late final double Function(double zoom) scaleFactor;

  AnimatedMarker({
    required this.key,
    required this.point,
    required this.child,
    this.size = const Size.square(30),
    this.sizeUnit = SizeUnit.pixels,
    this.anchor = Alignment.center,
    this.rotate = false,
    this.animateInBuilder = _defaultAnimateBuilder,
    this.animateOutBuilder = _defaultAnimateBuilder,
    this.animateInCurve = Curves.elasticOut,
    this.animateOutCurve = Curves.elasticOut,
    this.animateInDuration = const Duration(milliseconds: 600),
    this.animateOutDuration = const Duration(milliseconds: 600),
    this.animateInDelay = Duration.zero,
    this.animateOutDelay = Duration.zero,
  }) {
    if (sizeUnit == SizeUnit.pixels) {
      scaleFactor = _pixels;
    }
    else {
      scaleFactor = _meters;
    }
  }


  double _pixels(double zoom) => 1;


  double _meters(double zoom) {
    return 1 / metersPerPixel(point.latitude, zoom);
  }
}


enum SizeUnit {
  pixels,
  meters
}