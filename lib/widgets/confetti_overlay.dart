import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class ConfettiOverlay extends StatefulWidget {
  final Widget child;
  final bool play;

  const ConfettiOverlay({
    super.key,
    required this.child,
    this.play = false,
  });

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  late ConfettiController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.play) _controller.play();
  }

  @override
  void didUpdateWidget(ConfettiOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.play && !oldWidget.play) {
      _controller.play();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _controller,
            blastDirection: pi / 2,
            maxBlastForce: 12,
            minBlastForce: 4,
            emissionFrequency: 0.05,
            numberOfParticles: 15,
            gravity: 0.1,
            colors: [
              colors.primary,
              colors.secondary,
              colors.tertiary,
              colors.primaryContainer,
              Colors.white,
              colors.secondaryContainer,
            ],
          ),
        ),
      ],
    );
  }
}
