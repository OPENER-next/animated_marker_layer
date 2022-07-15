import 'package:flutter/widgets.dart';

class AnimatedMarkerWidget extends StatefulWidget {
  final Widget Function(BuildContext, Animation<double>) builder;

  final Key markerKey;

  final AnimationDirection animationDirection;

  final Duration animateInDuration;

  final Duration animateOutDuration;

  final Duration animateInDelay;

  final Duration animateOutDelay;

  final Curve animateInCurve;

  final Curve animateOutCurve;

  const AnimatedMarkerWidget({
    Key? key,
    required this.builder,
    required this.markerKey,
    this.animationDirection = AnimationDirection.animateIn,
    this.animateInDuration = const Duration(milliseconds: 600),
    this.animateOutDuration = const Duration(milliseconds: 600),
    this.animateInDelay = Duration.zero,
    this.animateOutDelay = Duration.zero,
    this.animateInCurve = Curves.elasticOut,
    this.animateOutCurve = Curves.elasticOut,
  }) : super(key: key);


  @override
  State<AnimatedMarkerWidget> createState() => _AnimatedMarkerWidgetState();
}

class _AnimatedMarkerWidgetState extends State<AnimatedMarkerWidget> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this);

  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller.addStatusListener((status) {
      // extra checks ensure that status changes triggered by the code itself are ignored
      if (status == AnimationStatus.dismissed && widget.animationDirection == AnimationDirection.animateOut) {
        AnimatedMarkerRemoveNotification(
          markerKey: widget.markerKey
        ).dispatch(context);
      }
    });

    _controller.addListener(() {
      setState(() { /* rebuild on animation */ });
    });

    _update();
  }


  @override
  void didUpdateWidget(covariant AnimatedMarkerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    _update(oldWidget);
  }


  void _update([covariant AnimatedMarkerWidget? oldWidget]) {
    if (oldWidget?.animateInDuration != widget.animateInDuration ||
        oldWidget?.animateOutDuration != widget.animateOutDuration ||
        oldWidget?.animateInCurve != widget.animateInCurve ||
        oldWidget?.animateOutCurve != widget.animateOutCurve ||
        oldWidget?.animateInDelay != widget.animateInDelay ||
        oldWidget?.animateOutDelay != widget.animateOutDelay
    ) {
      final totalInDuration = widget.animateInDuration + widget.animateInDelay;
      final totalOutDuration = widget.animateOutDuration + widget.animateOutDelay;

      _controller.duration = totalInDuration;
      _controller.reverseDuration = totalOutDuration;

      final startShift =  widget.animateInDelay.inMicroseconds / totalInDuration.inMicroseconds;
      final endShift = widget.animateOutDelay.inMicroseconds / totalOutDuration.inMicroseconds;

      _animation = CurvedAnimation(
        parent: _controller,
        curve: Interval(
          startShift, 1,
          curve: widget.animateInCurve
        ),
        reverseCurve: Interval(
          0, 1 - endShift,
          curve: widget.animateOutCurve
        ),
      );
    }
    if (oldWidget?.animationDirection != widget.animationDirection) {
      if (widget.animationDirection == AnimationDirection.animateIn) {
        final from = _controller.isAnimating ? _animation.value : 0.0;
        _controller.forward(from: from);
      }
      else if (widget.animationDirection == AnimationDirection.animateOut) {
        final from = _controller.isAnimating ? _animation.value : 1.0;
        // this may also immediately trigger an animation status change,
        // because of that the status listener contains some additional logic
        _controller.reverse(from: from);
      }
      // if AnimationDirection.none and the controller is not animating
      // set the animation to its finish value
      else if (!_controller.isAnimating) {
        _controller.value = 1;
      }
    }
  }


  @override
  Widget build(BuildContext context) => widget.builder(context, _animation);


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}


enum AnimationDirection {
  animateIn,
  animateOut,
  none
}


class AnimatedMarkerRemoveNotification extends Notification {
  final Key markerKey;

  AnimatedMarkerRemoveNotification({
    required this.markerKey
  });
}