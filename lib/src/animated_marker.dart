
import 'package:animated_marker_layer/src/size_utils.dart';
import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

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

  final Alignment anchor;

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

  late final Size Function(double zoom) pixelSize;

  AnimatedMarker({
    required this.key,
    required this.point,
    required this.child,
    this.size = const Size.square(30),
    SizeUnit sizeUnit = SizeUnit.pixels,
    this.anchor = Alignment.center,
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
      pixelSize = _pixels;
    }
    else {
      pixelSize = _meters;
    }
  }


  Size _pixels(double zoom) => size;


  Size _meters(double zoom) {
    return calcSizeFromMeter(size, point, zoom);
  }
}


enum SizeUnit {
  pixels,
  meters
}