import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';

/// Reusable confetti overlay. Place as a full-screen Stack child.
///
/// Key fix: when using BlastDirectionality.explosive, do NOT set
/// blastDirection. Let the library handle random directions.
class ConfettiOverlay extends StatelessWidget {
  final ConfettiController controller;
  final AppState? appState;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.appState,
  });

  List<Color> _getColors() {
    // Always rainbow
    return const [
      Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D),
      Color(0xFF95E1D3), Color(0xFFF38181), Color(0xFFAA96DA),
      Color(0xFF2196F3), Color(0xFFFF9800),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final mode = appState?.confettiMode ?? 0;
    final intensity = appState?.confettiIntensity ?? 0.7;

    // Base particle count scaled by intensity
    final particleCount = (20 + intensity * 60).round();

    switch (mode) {
      case 1: // Rain
        return _rain(particleCount, intensity);
      case 2: // Side spray
        return _sideSpray(particleCount, intensity);
      case 3: // Corner burst
        return _cornerBurst(particleCount, intensity);
      default: // Explosion (center)
        return _explosion(particleCount, intensity);
    }
  }

  /// Center explosion - particles spread in all directions
  Widget _explosion(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.center,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          // Do NOT set blastDirection when explosive
          numberOfParticles: count + 20, // more particles for fuller effect
          maxBlastForce: 20 + intensity * 25, // 20~45
          minBlastForce: 8 + intensity * 12, // 8~20
          gravity: 0.03 + intensity * 0.07, // 0.03~0.10, slow fall for float
          emissionFrequency: 0.04 + intensity * 0.04, // 0.04~0.08
          particleDrag: 0.02 + intensity * 0.03, // air resistance
          shouldLoop: false,
          colors: _getColors(),
          // Do NOT set createParticlePath or min/max size - let library handle
        ),
      ),
    );
  }

  /// Rain - falls from top
  Widget _rain(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 1.5708, // pi/2, straight down
          numberOfParticles: count,
          maxBlastForce: 2 + intensity * 5, // gentle fall
          minBlastForce: 1 + intensity * 2,
          gravity: 0.05 + intensity * 0.1,
          emissionFrequency: 0.05 + intensity * 0.05,
          shouldLoop: false,
          colors: _getColors(),
          minimumSize: const Size(6, 4),
          maximumSize: const Size(12, 6),
        ),
      ),
    );
  }

  /// Side spray - shoots from left
  Widget _sideSpray(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 0, // right
          numberOfParticles: count,
          maxBlastForce: 15 + intensity * 30,
          minBlastForce: 8 + intensity * 12,
          gravity: 0.1 + intensity * 0.1,
          emissionFrequency: 0.03 + intensity * 0.04,
          shouldLoop: false,
          colors: _getColors(),
          minimumSize: const Size(8, 4),
          maximumSize: const Size(16, 8),
        ),
      ),
    );
  }

  /// Corner burst - shoots from top-left corner
  Widget _cornerBurst(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 0.7854, // pi/4, diagonal
          numberOfParticles: count,
          maxBlastForce: 20 + intensity * 30,
          minBlastForce: 10 + intensity * 15,
          gravity: 0.1 + intensity * 0.15,
          emissionFrequency: 0.02 + intensity * 0.03,
          shouldLoop: false,
          colors: _getColors(),
          minimumSize: const Size(8, 4),
          maximumSize: const Size(16, 8),
        ),
      ),
    );
  }
}
