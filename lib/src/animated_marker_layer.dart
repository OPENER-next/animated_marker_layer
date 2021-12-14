import 'package:diffutil_dart/diffutil.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/plugin_api.dart';

import 'animated_marker.dart';
import 'animated_marker_widget.dart';

// TODO: hide via animation elements on threshold -> maybe introduce another hiddenArray

class AnimatedMarkerLayer extends StatefulWidget {
  final List<AnimatedMarker> markers;

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
  _AnimatedMarkerLayerState createState() => _AnimatedMarkerLayerState();
}

class _AnimatedMarkerLayerState extends State<AnimatedMarkerLayer> {

  late MapState map;

  final _cachedMarkers = <AnimatedMarker>[];

  final _newMarkers = <Key, AnimatedMarker>{};

  final _removedMarkers = <Key, AnimatedMarker>{};

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
  void didUpdateWidget(covariant AnimatedMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
    _refreshPixelCache();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    map = MapState.maybeOf(context)!;

    map.onMoved.listen((_) {
      if (map.zoom != _previousZoom) {
        _refreshPixelCache();
        // cache last zoom level to detect potential optimizations
        _previousZoom = map.zoom;
      }
      setState(() {});
    });

    _refreshPixelCache();
  }


  _update() {
    final diffResult = calculateListDiff<AnimatedMarker>(
      _cachedMarkers, widget.markers,
      detectMoves: true,
      equalityChecker: _equalityCheck
    );

    // diff result is returned in reverse so reverse it to get the original order
    for (final update in diffResult.getUpdatesWithData().toList().reversed) {
      update.when(
        insert: _addMarker,
        remove: _removeMarker,
        // TODO: check if this is needed to update markers
        change: (index, oldData, newData) {},
        move: (from, to, data) {},
      );
    }

    _cachedMarkers
      ..clear()
      ..addAll(widget.markers);
  }


  bool _equalityCheck(AnimatedMarker marker1, AnimatedMarker marker2) {
    return marker1.key == marker2.key;
  }


  void _addMarker(int index, AnimatedMarker newMarker) {
    _newMarkers[newMarker.key] = newMarker;
    // in case the added marker was shortly removed, remove it from the collection
    _removedMarkers.remove(newMarker.key);
  }


  void _removeMarker(int index, AnimatedMarker removedMarker) {
    _removedMarkers[removedMarker.key] = removedMarker;
    // in case the removed marker was shortly added, remove it from the collection
    _newMarkers.remove(removedMarker.key);
  }



  void _refreshPixelCache() {
    _pixelPositionCache.clear();
    _pixelSizeCache.clear();

    for (final marker in _cachedMarkers) {
      _pixelPositionCache.add(map.project(marker.point));
      _pixelSizeCache.add(marker.pixelSize(map.zoom));
    }
  }


  /// Returns null if the marker widget is not visible.

  Widget? _buildMarkerWidget(AnimatedMarker marker, {
    AnimationDirection? animationDirection,
    CustomPoint? cachedPixelPosition,
    Size? cachedPixelSize,
  }) {
    final CustomPoint pxPoint = cachedPixelPosition ?? map.project(marker.point);
    final Size size = cachedPixelSize ?? marker.pixelSize(map.zoom);

    // shift position to anchor
    final shift = marker.anchor.alongSize(size);

    final sw = CustomPoint(pxPoint.x + shift.dx, pxPoint.y - shift.dy);
    final ne = CustomPoint(pxPoint.x - shift.dx, pxPoint.y + shift.dy);

    final isVisible = map.pixelBounds.containsPartialBounds(Bounds(sw, ne));

    if (!isVisible || size.longestSide <= 1) {
      return null;
    }

    final pos = pxPoint - map.getPixelOrigin();

    return Positioned(
      key: marker.key,
      width: size.width,
      height: size.height,
      left: pos.x - shift.dx,
      top: pos.y - shift.dy,
      child: animationDirection == null
        ? marker.child
        : AnimatedMarkerWidget(
          animationDirection: animationDirection,
          animateInCurve: marker.animateInCurve,
          animateOutCurve: marker.animateOutCurve,
          animateInDuration: marker.animateInDuration,
          animateOutDuration: marker.animateOutDuration,
          animateInBuilder:  marker.animateInBuilder,
          animateOutBuilder: marker.animateOutBuilder,
          animateInDelay: marker.animateInDelay,
          animateOutDelay: marker.animateOutDelay,
          child: marker.child,
      )
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
        // remove element
        return true;
      }
      markerWidgets.add(markerWidget);
      return false;
    });

    for (var i = 0; i < _cachedMarkers.length; i++) {
      final marker = _cachedMarkers[i];

      Widget? markerWidget;
      if (_newMarkers.containsKey(marker.key)) {
        markerWidget = _buildMarkerWidget(
          marker,
          cachedPixelPosition: _pixelPositionCache[i],
          cachedPixelSize: _pixelSizeCache[i],
          animationDirection: AnimationDirection.animateIn
        );

        if (markerWidget == null) {
          _newMarkers.remove(marker.key);
        }
      }
      else {
        markerWidget = _buildMarkerWidget(
          marker,
          cachedPixelPosition: _pixelPositionCache[i],
          cachedPixelSize: _pixelSizeCache[i]
        );
      }

      if (markerWidget != null) {
        markerWidgets.add(markerWidget);
      }
    }

    return markerWidgets;
  }


  bool _handleAnimationEnd(AnimateMarkerEndNotification notification) {
    final positionedWidget = notification.context.findAncestorWidgetOfExactType<Positioned>();
    final key = positionedWidget!.key;

    switch (notification.animationDirection) {
      case AnimationDirection.animateIn:
        setState(() {
          _newMarkers.remove(key);
        });
      break;
      case AnimationDirection.animateOut:
        setState(() {
          _removedMarkers.remove(key);
        });
      break;
      default:
    }

    return true;
  }


  @override
  Widget build(BuildContext context) {
    return NotificationListener<AnimateMarkerEndNotification>(
      onNotification: _handleAnimationEnd,
      child: Stack(
        children: _buildMarkerWidgets()
      )
    );
  }
}