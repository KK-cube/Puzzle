import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';

class TitleScreen extends ConsumerWidget {
  const TitleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7E7C6), Color(0xFFF0F4EF), Color(0xFFD7E6F5)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF17324D),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Flutter + Flame Puzzle MVP',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Line Pulse',
                          style: TextStyle(
                            fontSize: 52,
                            height: 0.94,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -2,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You have 30 seconds. Drag tiles directly to swap lines, build matches, and earn bonus time with bigger clears.',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.4,
                            color: Color(0xFF314155),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: [
                            _InfoCard(
                              label: 'Best Score',
                              value: '${state.bestScore}',
                            ),
                            const _InfoCard(label: 'Timer', value: '30 sec'),
                            const _InfoCard(label: 'Board', value: '7 x 7'),
                            const _InfoCard(
                              label: 'Rotations',
                              value: '3 per run',
                            ),
                          ],
                        ),
                        const SizedBox(height: 34),
                        FilledButton.icon(
                          onPressed: () async {
                            await backgroundMusic.ensurePlaying();
                            controller.startNewGame();
                          },
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Start Run'),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF17324D),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Clear 3 tiles for +1 second. Clear 4 or more tiles in one wave for +2 seconds. Rotations still use the center-tap plus CW / CCW buttons.',
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: Color(0xFF556273),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCAD5E2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5F6C7B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ],
      ),
    );
  }
}
