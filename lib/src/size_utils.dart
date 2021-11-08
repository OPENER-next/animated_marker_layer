
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:latlong2/latlong.dart';

/// Earth circumference in meters
const _earthCircumference = 2 * pi * earthRadius;

const _piFraction = pi / 180;

double _metersPerPixel(double latitude, double zoomLevel) {
  final latitudeRadians = latitude * _piFraction;
  return _earthCircumference * cos(latitudeRadians) / pow(2, zoomLevel + 8);
}

Size calcSizeFromMeter(Size size, LatLng point, double zoom) {
  return size / _metersPerPixel(point.latitude, zoom);
}