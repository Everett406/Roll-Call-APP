import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import '../providers/app_state.dart';

/// Reusable confetti overlay.
///
/// Key design decisions for best visual effect:
/// - NO custom createParticlePath (use library's default rect+circle mix)
/// - NO min/max size constraints (let library vary sizes naturally)
/// - Lower gravity for longer float time
/// - Higher particle count for fuller coverage
class ConfettiOverlay extends StatelessWidget {
  final ConfettiController controller;
  final AppState? appState;

  const ConfettiOverlay({
    super.key,
    required this.controller,
    this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final mode = appState?.confettiMode ?? 0;
    final intensity = appState?.confettiIntensity ?? 0.7;

    // Scale particle count by intensity: low=15, default=32, high=50
    final particleCount = (15 + intensity * 35).round();

    switch (mode) {
      case 1: // Rain
        return _rainMode(particleCount, intensity);
      case 2: // Side
        return _sideMode(particleCount, intensity);
      case 3: // Corner
        return _cornerMode(particleCount, intensity);
      default: // Explosion
        return _explosionMode(particleCount, intensity);
    }
  }

  // Center explosion - most common, celebratory
  Widget _explosionMode(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: count,
          maxBlastForce: 20 + intensity * 30,
          minBlastForce: 5 + intensity * 15,
          gravity: 0.05 + intensity * 0.08,
          emissionFrequency: 0.03 + intensity * 0.04,
          particleDrag: 0.01 + intensity * 0.02,
          shouldLoop: false,
          colors: _rainbowColors,
        ),
      ),
    );
  }

  // Rain from top
  Widget _rainMode(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 1.5708, // straight down
          numberOfParticles: count,
          maxBlastForce: 2 + intensity * 6,
          minBlastForce: 1 + intensity * 3,
          gravity: 0.03 + intensity * 0.05,
          emissionFrequency: 0.04 + intensity * 0.06,
          shouldLoop: false,
          colors: _rainbowColors,
        ),
      ),
    );
  }

  // Side spray from left
  Widget _sideMode(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 0,
          numberOfParticles: count,
          maxBlastForce: 15 + intensity * 35,
          minBlastForce: 5 + intensity * 15,
          gravity: 0.04 + intensity * 0.06,
          emissionFrequency: 0.03 + intensity * 0.05,
          shouldLoop: false,
          colors: _rainbowColors,
        ),
      ),
    );
  }

  // Corner burst from top-left
  Widget _cornerMode(int count, double intensity) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topLeft,
        child: ConfettiWidget(
          confettiController: controller,
          blastDirectionality: BlastDirectionality.directional,
          blastDirection: 0.7854, // diagonal
          numberOfParticles: count,
          maxBlastForce: 18 + intensity * 32,
          minBlastForce: 8 + intensity * 18,
          gravity: 0.04 + intensity * 0.08,
          emissionFrequency: 0.03 + intensity * 0.04,
          shouldLoop: false,
          colors: _rainbowColors,
        ),
      ),
    );
  }

  static const _rainbowColors = [
    Color(0xFFFF6B6B), Color(0xFF4ECDC4), Color(0xFFFFE66D),
    Color(0xFF95E1D3), Color(0xFFF38181), Color(0xFFAA96DA),
    Color(0xFF2196F3), Color(0xFFFF9800), Color(0xFFE91E63),
    Color(0xFF4CAF50),
  ];
}
