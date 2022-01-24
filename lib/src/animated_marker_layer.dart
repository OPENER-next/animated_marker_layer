import 'dart:async';
import 'dart:developer';

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

class _AnimatedMarkerLayerState extends State<AnimatedMarkerLayer> with ChangeNotifier {

  late MapState map;

  final _cachedMarkers = <AnimatedMarker>[];

  final _newMarkers = <Key, AnimatedMarker>{};

  final _removedMarkers = <Key, AnimatedMarker>{};

  StreamSubscription? _streamSubscription;

  @override
  void initState() {
    super.initState();
    _update();
  }


  @override
  void didUpdateWidget(covariant AnimatedMarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _update();
  }


  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    map = MapState.maybeOf(context)!;

    // notify listeners whenever the map is moved
    // this is done in order to trigger a repaint in the flow delegate
    _streamSubscription?.cancel();
    _streamSubscription = map.onMoved.listen((_) => notifyListeners());
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


  /// Returns null if the marker widget is not visible.

  Widget? _buildMarkerWidget(AnimatedMarker marker, {
    AnimationDirection? animationDirection,
  }) {
    // Wrap in animated marker widget if animation direction is given
    final markerWidget = animationDirection == null
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
          child: marker.child
        );

    return SizedBox.fromSize(
      key: marker.key,
      size: marker.size,
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
          animationDirection: AnimationDirection.animateIn
        );

        if (markerWidget == null) {
          _newMarkers.remove(marker.key);
        }
      }
      else {
        markerWidget = _buildMarkerWidget(
          marker,
        );
      }

      if (markerWidget != null) {
        markerWidgets.add(markerWidget);
      }
    }

    return markerWidgets;
  }


  bool _handleAnimationEnd(AnimateMarkerEndNotification notification) {
    final positionedWidget = notification.context.findAncestorWidgetOfExactType<SizedBox>();
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
    return RepaintBoundary(
      child: NotificationListener<AnimateMarkerEndNotification>(
        onNotification: _handleAnimationEnd,
        child: Flow.unwrapped(
          delegate: _AnimatedMarkerLayerDelegate(
            markerLayerState: this
          ),
          children: _buildMarkerWidgets()
        )
      )
    );
  }


  @override
  void dispose() {
    super.dispose();
    _streamSubscription?.cancel();
  }
}




class _AnimatedMarkerLayerDelegate extends FlowDelegate {

  final _AnimatedMarkerLayerState markerLayerState;

  final _pixelPositionCache = <CustomPoint<num>>[];

  double _lastZoomLevel = -1;

  _AnimatedMarkerLayerDelegate({
    required this.markerLayerState,
  }) : super(repaint: markerLayerState);


  @override
  bool shouldRepaint(_AnimatedMarkerLayerDelegate oldDelegate) {
    if (markerLayerState != oldDelegate.markerLayerState) {
      _pixelPositionCache.clear();
      return true;
    }
    return false;
  }


  @override
  bool shouldRelayout(covariant FlowDelegate oldDelegate) {
    return false;
  }


  @override
  void paintChildren(FlowPaintingContext context) {
    Timeline.startSync("Doing Something");
    final map = markerLayerState.map;

    final mapPixelOrigin = map.getPixelOrigin();

    final rebuildCache = _lastZoomLevel != map.zoom;

    _lastZoomLevel = map.zoom;

    for (int i = 0; i < context.childCount; i++) {
      final marker = markerLayerState._cachedMarkers[i];

      final childSize = context.getChildSize(i)!;
      // shift position to anchor
      final offset = marker.anchor.alongSize(childSize);

      final CustomPoint<num> absolutePixelPosition;

      if (rebuildCache) {
        absolutePixelPosition = map.project(marker.point);

        if (i >= _pixelPositionCache.length) {
          _pixelPositionCache.add(absolutePixelPosition);
        }
        else {
          _pixelPositionCache[i] = absolutePixelPosition;
        }
      }
      else {
        absolutePixelPosition = _pixelPositionCache[i];
      }

      final sw = CustomPoint(absolutePixelPosition.x + offset.dx, absolutePixelPosition.y - offset.dy);
      final ne = CustomPoint(absolutePixelPosition.x - offset.dx, absolutePixelPosition.y + offset.dy);

      // only paint marker if inside viewport
      if (map.pixelBounds.containsPartialBounds(Bounds(sw, ne)) && childSize.longestSide > 1) {
        final relativePixelPosition = absolutePixelPosition - mapPixelOrigin;

        final transformationMatrix = Matrix4.translationValues(
          relativePixelPosition.x.toDouble(),
          relativePixelPosition.y.toDouble(),
          0,
        );
        // counter rotate marker to the map rotation if it should stay steady
        if (!marker.rotate) {
          transformationMatrix.rotateZ(-map.rotationRad);
        }

        // scale widget size if it's given in any other unit then pixels
        if (marker.sizeUnit != SizeUnit.pixels) {
          final scale = marker.scaleFactor(map.zoom);
          transformationMatrix.scale(scale, scale);
        }

        // apply anchor offset
        transformationMatrix.translate(-offset.dx, -offset.dy);

        context.paintChild(i, transform: transformationMatrix);
      }
    }
    Timeline.finishSync();
  }
}
