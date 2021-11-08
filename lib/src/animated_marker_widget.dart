import 'package:flutter/widgets.dart';

class AnimatedMarkerWidget extends StatefulWidget {
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

  final Widget child;

  final AnimationDirection animationDirection;

  final Duration animateInDuration;

  final Duration animateOutDuration;

  final Duration animateInDelay;

  final Duration animateOutDelay;

  final Curve animateInCurve;

  final Curve animateOutCurve;

  const AnimatedMarkerWidget({
    Key? key,
    required this.animateInBuilder,
    required this.animateOutBuilder,
    required this.child,
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

  late Widget Function(
    BuildContext context,
    Animation<double> animation,
    Widget child
  ) _builder = widget.animateInBuilder;


  @override
  void initState() {
    super.initState();

    _controller.addStatusListener((status) {
      // extra checks ensure that status changes triggered by the code itself are ignored
      if (
        (status == AnimationStatus.completed && widget.animationDirection == AnimationDirection.animateIn) ||
        (status == AnimationStatus.dismissed && widget.animationDirection == AnimationDirection.animateOut)
      ) {
        AnimateMarkerEndNotification(
          context: context,
          animationDirection: widget.animationDirection
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
      _controller.duration = widget.animateInDuration + widget.animateInDelay;
      _controller.reverseDuration = widget.animateOutDuration + widget.animateOutDelay;

      final startShift = widget.animateInDelay.inMicroseconds / widget.animateInDuration.inMicroseconds;
      final endShift = widget.animateOutDelay.inMicroseconds / widget.animateOutDuration.inMicroseconds;

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
    if (
      oldWidget?.animateInBuilder != widget.animateInBuilder &&
      _controller.status == AnimationStatus.forward
    ) {
      _builder = widget.animateInBuilder;
    }
    if (
      oldWidget?.animateOutBuilder != widget.animateOutBuilder &&
      _controller.status == AnimationStatus.reverse
    ) {
      _builder = widget.animateOutBuilder;
    }
    if (oldWidget?.animationDirection != widget.animationDirection) {
      if (widget.animationDirection == AnimationDirection.animateIn) {
        _builder = widget.animateInBuilder;

        final from = _controller.isAnimating ? _animation.value : 0.0;
        _controller.forward(from: from);
      }
      else  {
        _builder = widget.animateOutBuilder;

        final from = _controller.isAnimating ? _animation.value : 1.0;
        // this may also immediately trigger an animation status change,
        // because of that the status listener contains some additional logic
        _controller.reverse(from: from);
      }
    }
  }


  @override
  Widget build(BuildContext context) => _builder(context, _animation, widget.child);


  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}



enum AnimationDirection {
  animateIn,
  animateOut
}


class AnimateMarkerEndNotification extends Notification {
  final BuildContext context;
  final AnimationDirection animationDirection;

  AnimateMarkerEndNotification({
    required this.context,
    required this.animationDirection
  });
}