import 'dart:async';

import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/plugin_api.dart';

import 'animated_marker.dart';
import 'animated_marker_widget.dart';

// TODO: hide via animation elements on threshold -> maybe introduce another hiddenArray

class AnimatedMarkerLayer<T extends AnimatedMarker> extends StatefulWidget {

  /// This list must be immutable, i.a. should not be modified.

  final List<T> markers;

  /// The minimal marker size until markers will be hidden

  final double sizeThreshold;

  /// The zoom level from which upon markers will be hidden

  final double zoomThreshold;

  const AnimatedMarkerLayer({
    Key? key,
    this.markers = const [],
    this.sizeThreshold = double.infinity,
    this.zoomThreshold = 0
  }) : super(key: key);

  @override
  _AnimatedMarkerLayerState<T> createState() => _AnimatedMarkerLayerState<T>();
}


class _AnimatedMarkerLayerState<T extends AnimatedMarker> extends State<AnimatedMarkerLayer<T>> {

  late MapState _map;

  StreamSubscription? _streamSubscription;

  final _newMarkers = <Key>{};

  final _removedMarkers = <Key, T>{};

  // done for performance optimizations

  var _previousZoom = -1.0;

  final _pixelPositionCache = <CustomPoint>[];

  final _pixelSizeCache = <Size>[];

  @override
  void initState() {
    super.initState();
    _update();
  }


  @override
  void didUpdateWidget(covariant AnimatedMarkerLayer<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update(oldWidget.markers);
    _refreshPixelCache();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    _streamSubscription?.cancel();

    _map = MapState.maybeOf(context)!;

    _streamSubscription = _map.onMoved.listen((_) {
      if (_map.zoom != _previousZoom) {
        _refreshPixelCache();
        // cache last zoom level to detect potential optimizations
        _previousZoom = _map.zoom;
      }
      setState(() {});
    });

    _refreshPixelCache();
  }


  _update([ List<T>oldMarkers = const [] ]) {
    final diffResult = calculateListDiff<T>(
      oldMarkers, widget.markers,
      equalityChecker: _equalityCheck
    );

    // diff result is returned in reverse so reverse it to get the original order
    for (final update in diffResult.getUpdatesWithData().toList().reversed) {
      update.when(
        insert: _addMarker,
        remove: _removeMarker,
        change: (index, oldData, newData) {},
        move: (from, to, data) {},
      );
    }
  }


  bool _equalityCheck(T marker1, T marker2) => marker1.key == marker2.key;


  void _addMarker(int index, T newMarker) {
    _newMarkers.add(newMarker.key);
    // in case the added marker was shortly removed, remove it from the collection
    _removedMarkers.remove(newMarker.key);
  }


  void _removeMarker(int index, T removedMarker) {
    _removedMarkers[removedMarker.key] = removedMarker;
  }


  void _refreshPixelCache() {
    _pixelPositionCache.clear();
    _pixelSizeCache.clear();

    for (final marker in widget.markers) {
      _pixelPositionCache.add(_map.project(marker.point));
      _pixelSizeCache.add(marker.pixelSize(_map.zoom));
    }
  }


  /// Returns null if the marker widget is not visible.

  Widget? _buildMarkerWidget(T marker, {
    required AnimationDirection animationDirection,
    CustomPoint? cachedPixelPosition,
    Size? cachedPixelSize,
  }) {
    final CustomPoint pxPoint = cachedPixelPosition ?? _map.project(marker.point);
    final Size size = cachedPixelSize ?? marker.pixelSize(_map.zoom);

    // shift position to anchor
    final shift = marker.anchor.alongSize(size);

    final sw = CustomPoint(pxPoint.x + shift.dx, pxPoint.y - shift.dy);
    final ne = CustomPoint(pxPoint.x - shift.dx, pxPoint.y + shift.dy);

    final isVisible = _map.pixelBounds.containsPartialBounds(Bounds(sw, ne));

    if (!isVisible || size.longestSide <= 1) {
      return null;
    }

    final pos = pxPoint - _map.getPixelOrigin();

    // Wrap in animated marker widget if animation direction is given
    Widget markerWidget = AnimatedMarkerWidget(
      animationDirection: animationDirection,
      animateInCurve: marker.animateInCurve,
      animateOutCurve: marker.animateOutCurve,
      animateInDuration: marker.animateInDuration,
      animateOutDuration: marker.animateOutDuration,
      animateInDelay: marker.animateInDelay,
      animateOutDelay: marker.animateOutDelay,
      markerKey: marker.key,
      builder: marker.build
    );

    // Counter rotate marker to the map rotation if it should stay steady
    markerWidget = !marker.rotate
      ? Transform.rotate(
          angle: -_map.rotationRad,
          alignment: marker.anchor,
          child: markerWidget,
        )
      : markerWidget;

    return Positioned(
      key: marker.key,
      width: size.width,
      height: size.height,
      left: pos.x - shift.dx,
      top: pos.y - shift.dy,
      child: markerWidget
    );
  }


  List<Widget> _buildMarkerWidgets() {
    final markerWidgets = <Widget>[];

    _removedMarkers.removeWhere((key, marker) {
      final markerWidget = _buildMarkerWidget(
        marker,
        animationDirection: AnimationDirection.animateOut
      );

      if (markerWidget == null) {
        // remove off screen markers immediately
        return true;
      }
      markerWidgets.add(markerWidget);
      return false;
    });

    for (var i = 0; i < widget.markers.length; i++) {
      final marker = widget.markers[i];
      final markerWidget = _buildMarkerWidget(
        marker,
        // if marker key was present in _newMarkers animate it, else not
        animationDirection: _newMarkers.remove(marker.key)
          ? AnimationDirection.animateIn
          : AnimationDirection.none,
        cachedPixelPosition: _pixelPositionCache[i],
        cachedPixelSize: _pixelSizeCache[i]
      );

      if (markerWidget != null) {
        markerWidgets.add(markerWidget);
      }
    }

    return markerWidgets;
  }


  bool _handleAnimationEnd(AnimatedMarkerRemoveNotification notification) {
    // to prevent "setState() or markNeedsBuild() called during build."" error
    WidgetsBinding.instance.addPostFrameCallback((_) {
      setState(() {
        _removedMarkers.remove(notification.markerKey);
      });
    });

    return true;
  }


  @override
  Widget build(BuildContext context) {
    return NotificationListener<AnimatedMarkerRemoveNotification>(
      onNotification: _handleAnimationEnd,
      child: Stack(
        children: _buildMarkerWidgets()
      )
    );
  }


  @override
  void dispose() {
    _streamSubscription?.cancel();
    super.dispose();
  }
}
