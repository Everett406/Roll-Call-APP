import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';

/// A reusable confetti overlay widget with full customization support.
///
/// Usage:
/// ```dart
/// ConfettiOverlay(
///   controller: myController,
///   appState: appState,  // optional, uses config from AppState
/// )
/// ```
class ConfettiOverlay extends StatelessWidget {
  final ConfettiController controller;
  final AppState? appState;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.appState,
  });

  List<Color> _getColors(BuildContext context, AppState? state) {
    final theme = Theme.of(context);
    if (state == null) {
      return const [
        Color(0xFF4CAF50), Color(0xFFF44336), Color(0xFF2196F3),
        Color(0xFFFFC107), Color(0xFF9C27B0), Color(0xFFFF9800),
        Color(0xFF00BCD4), Color(0xFFE91E63),
      ];
    }
    switch (state.confettiColor) {
      case 0: return [theme.colorScheme.primary];
      case 1: return [theme.colorScheme.secondary];
      case 2: return [theme.colorScheme.tertiary];
      default:
        return const [
          Color(0xFF4CAF50), Color(0xFFF44336), Color(0xFF2196F3),
          Color(0xFFFFC107), Color(0xFF9C27B0), Color(0xFFFF9800),
          Color(0xFF00BCD4), Color(0xFFE91E63),
        ];
    }
  }

  Path Function(Size) _getParticleBuilder(AppState? state) {
    return (size) {
      final shape = state?.confettiShape ?? 2;
      if (shape == 0) {
        // Circle
        return Path()
          ..addOval(Rect.fromCenter(
            center: Offset.zero,
            width: size.width,
            height: size.height,
          ));
      } else if (shape == 1) {
        // Square
        return Path()
          ..addRect(Rect.fromCenter(
            center: Offset.zero,
            width: size.width * 0.7,
            height: size.height,
          ));
      } else {
        // Mixed
        final rnd = math.Random();
        if (rnd.nextBool()) {
          return Path()
            ..addOval(Rect.fromCenter(
              center: Offset.zero,
              width: size.width,
              height: size.height,
            ));
        } else {
          return Path()
            ..addRect(Rect.fromCenter(
              center: Offset.zero,
              width: size.width * 0.7,
              height: size.height,
            ));
        }
      }
    };
  }

  (BlastDirectionality, double) _getMode(AppState? state) {
    final mode = state?.confettiMode ?? 0;
    switch (mode) {
      case 1: // Rain
        return (BlastDirectionality.directional, 3.14159 / 2);
      case 2: // Side
        return (BlastDirectionality.directional, 0);
      case 3: // Corner
        return (BlastDirectionality.directional, 5.49779);
      default: // Explosive
        return (BlastDirectionality.explosive, 0);
    }
  }

  Alignment _getAlignment(AppState? state) {
    final mode = state?.confettiMode ?? 0;
    switch (mode) {
      case 1: return Alignment.topCenter;    // Rain
      case 2: return Alignment.centerLeft;   // Side
      case 3: return Alignment.topLeft;      // Corner
      default: return Alignment.center;      // Explosive
    }
  }

  @override
  Widget build(BuildContext context) {
    final (directionality, blastDirection) = _getMode(appState);
    final intensity = appState?.confettiIntensity ?? 0.7;
    final particleCount = (30 + intensity * 70).round();

    return IgnorePointer(
      child: Align(
        alignment: _getAlignment(appState),
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: directionality,
          blastDirection: blastDirection,
          numberOfParticles: particleCount,
          maxBlastForce: 20 + intensity * 20,
          minBlastForce: 8 + intensity * 10,
          gravity: 0.2 + intensity * 0.15,
          emissionFrequency: 0.02 + intensity * 0.04,
          shouldLoop: false,
          colors: _getColors(context, appState),
          createParticlePath: _getParticleBuilder(appState),
        ),
      ),
    );
  }
}
