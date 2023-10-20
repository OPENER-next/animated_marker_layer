import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

import 'size_utils.dart';

typedef AnimatedMarkerBuilder<T extends AnimatedMarker> = Widget Function(
  BuildContext context, Animation<double> animation, T marker
);

class AnimatedMarker {
  final LatLng point;

  final AnimatedMarkerBuilder builder;

  final Key key;

  final Size size;

  final Alignment anchor;

  // If false the marker will be counter rotated on map rotation, else it will rotate with the map.

  final bool rotate;

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
    required this.builder,
    this.size = const Size.square(30),
    SizeUnit sizeUnit = SizeUnit.pixels,
    this.anchor = Alignment.center,
    this.rotate = false,
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


  Widget build(BuildContext context, Animation<double> animation) {
    return builder(context, animation, this);
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
