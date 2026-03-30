import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../application/game_session_state.dart';
import '../../domain/models.dart';
import '../puzzle_board_stage.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF3C7), Color(0xFFF2F7F1), Color(0xFFDDEBFF)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _HudChip(label: 'Score', value: '${state.score}'),
                  _HudChip(label: 'Best', value: '${state.bestScore}'),
                  _HudChip(
                    label: 'Rotations',
                    value: '${state.remainingRotations}',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 720,
                      maxHeight: 720,
                    ),
                    child: PuzzleBoardStage(state: state),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: state.chainBanner == null
                    ? const SizedBox(key: ValueKey('chain-empty'), height: 40)
                    : Container(
                        key: ValueKey(state.chainBanner),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17324D),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          state.chainBanner!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.icon(
                    onPressed: _canRotate(state)
                        ? () => controller.rotateSelection(
                            RotationDirection.counterClockwise,
                          )
                        : null,
                    icon: const Icon(Icons.rotate_left_rounded),
                    label: const Text('Rotate CCW'),
                  ),
                  FilledButton.icon(
                    onPressed: _canRotate(state)
                        ? () => controller.rotateSelection(
                            RotationDirection.clockwise,
                          )
                        : null,
                    icon: const Icon(Icons.rotate_right_rounded),
                    label: const Text('Rotate CW'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                state.selectedRotationCenter == null
                    ? 'Tap a center tile to arm a 3x3 rotation.'
                    : 'Rotation ready at row ${state.selectedRotationCenter!.row + 1}, column ${state.selectedRotationCenter!.column + 1}.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Color(0xFF4A5565)),
              ),
              const SizedBox(height: 8),
              const Text(
                'Drag the left rail to swap rows. Drag the top rail to swap columns. Invalid moves animate and snap back.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF657282)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  bool _canRotate(GameSessionState state) {
    return !state.inputLocked &&
        state.selectedRotationCenter != null &&
        state.remainingRotations > 0;
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 132,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD4DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF5D6A79),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
