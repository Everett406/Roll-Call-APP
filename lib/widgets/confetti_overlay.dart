import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// A reusable confetti overlay widget.
/// Place this as a full-screen overlay child, call controller.play() to fire.
class ConfettiOverlay extends StatefulWidget {
  final ConfettiController controller;
  final Alignment alignment;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.alignment = Alignment.topCenter,
  });

  factory ConfettiOverlay.explosion({
    Key? key,
    required ConfettiController controller,
  }) => ConfettiOverlay(
        key: key,
        controller: controller,
        alignment: Alignment.center,
      );

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiOverlayState extends State<ConfettiOverlay> {
  final _colors = const [
    Color(0xFF4CAF50),
    Color(0xFFF44336),
    Color(0xFF2196F3),
    Color(0xFFFFC107),
    Color(0xFF9C27B0),
    Color(0xFFFF9800),
    Color(0xFF00BCD4),
    Color(0xFFE91E63),
  ];

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: widget.alignment,
        child: ConfettiWidget(
          confettiController: widget.controller,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 40,
          maxBlastForce: 35,
          minBlastForce: 15,
          emissionFrequency: 0.04,
          gravity: 0.25,
          shouldLoop: false,
          colors: _colors,
          createParticlePath: (size) {
            // Mix of circles and rectangles for variety
            final rnd = math.Random();
            if (rnd.nextBool()) {
              // Circle
              return Path()
                ..addOval(Rect.fromCenter(
                  center: Offset.zero,
                  width: size.width,
                  height: size.height,
                ));
            } else {
              // Rectangle (paper-like)
              return Path()
                ..addRect(Rect.fromCenter(
                  center: Offset.zero,
                  width: size.width * 0.7,
                  height: size.height,
                ));
            }
          },
        ),
      ),
    );
  }
}
