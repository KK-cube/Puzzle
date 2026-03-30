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
    final rotateCounterClockwise = _canRotate(state)
        ? () => controller.rotateSelection(RotationDirection.counterClockwise)
        : null;
    final rotateClockwise = _canRotate(state)
        ? () => controller.rotateSelection(RotationDirection.clockwise)
        : null;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFEF3C7), Color(0xFFF2F7F1), Color(0xFFDDEBFF)],
        ),
      ),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact =
                constraints.maxWidth < 560 || constraints.maxHeight < 780;
            if (compact) {
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                child: Column(
                  children: [
                    _HudSection(state: state, compact: true),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: PuzzleBoardStage(state: state),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _ControlPanel(
                      state: state,
                      compact: true,
                      onRotateCounterClockwise: rotateCounterClockwise,
                      onRotateClockwise: rotateClockwise,
                    ),
                  ],
                ),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  _HudSection(state: state, compact: false),
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
                  _ControlPanel(
                    state: state,
                    compact: false,
                    onRotateCounterClockwise: rotateCounterClockwise,
                    onRotateClockwise: rotateClockwise,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool _canRotate(GameSessionState state) {
    return !state.inputLocked &&
        state.selectedRotationCenter != null &&
        state.remainingRotations > 0;
  }

  static String _formatTime(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}s';
  }
}

class _HudSection extends StatelessWidget {
  const _HudSection({required this.state, required this.compact});

  final GameSessionState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Row(
        children: [
          Expanded(
            child: _HudChip(
              label: 'Score',
              value: '${state.score}',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: 'Best',
              value: '${state.bestScore}',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: 'Time',
              value: GameScreen._formatTime(state.remainingTimeMs),
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: 'Rotations',
              value: '${state.remainingRotations}',
              compact: true,
            ),
          ),
        ],
      );
    }

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _HudChip(label: 'Score', value: '${state.score}'),
        _HudChip(label: 'Best', value: '${state.bestScore}'),
        _HudChip(
          label: 'Time',
          value: GameScreen._formatTime(state.remainingTimeMs),
        ),
        _HudChip(label: 'Rotations', value: '${state.remainingRotations}'),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({
    required this.state,
    required this.compact,
    required this.onRotateCounterClockwise,
    required this.onRotateClockwise,
  });

  final GameSessionState state;
  final bool compact;
  final VoidCallback? onRotateCounterClockwise;
  final VoidCallback? onRotateClockwise;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 12 : 16,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(compact ? 20 : 24),
        border: Border.all(color: const Color(0xFFD7E1EC)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: state.chainBanner == null
                ? const SizedBox.shrink()
                : Container(
                    key: ValueKey(state.chainBanner),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF17324D),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      state.chainBanner!,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: compact ? 14 : 16,
                      ),
                    ),
                  ),
          ),
          if (state.chainBanner != null) SizedBox(height: compact ? 10 : 12),
          if (compact)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRotateCounterClockwise,
                    icon: const Icon(Icons.rotate_left_rounded),
                    label: const Text('Rotate CCW'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRotateClockwise,
                    icon: const Icon(Icons.rotate_right_rounded),
                    label: const Text('Rotate CW'),
                  ),
                ),
              ],
            )
          else
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onRotateCounterClockwise,
                  icon: const Icon(Icons.rotate_left_rounded),
                  label: const Text('Rotate CCW'),
                ),
                FilledButton.icon(
                  onPressed: onRotateClockwise,
                  icon: const Icon(Icons.rotate_right_rounded),
                  label: const Text('Rotate CW'),
                ),
              ],
            ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            state.selectedRotationCenter == null
                ? state.remainingRotations > 0
                      ? 'Tap a center tile to arm a 3x3 rotation.'
                      : 'No rotations left in this run.'
                : 'Rotation ready at row ${state.selectedRotationCenter!.row + 1}, column ${state.selectedRotationCenter!.column + 1}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 13 : 14,
              color: const Color(0xFF4A5565),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            compact
                ? 'Drag any tile sideways to slide its column, or vertically to slide its row.'
                : 'Drag tiles directly: sideways slides a column, vertical movement slides a row. Invalid moves animate and snap back.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              color: const Color(0xFF657282),
            ),
          ),
        ],
      ),
    );
  }
}

class _HudChip extends StatelessWidget {
  const _HudChip({
    required this.label,
    required this.value,
    this.compact = false,
  });

  final String label;
  final String value;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: compact ? null : 132,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 16,
        vertical: compact ? 10 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.84),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(color: const Color(0xFFD4DEE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: const Color(0xFF5D6A79),
              fontWeight: FontWeight.w600,
              fontSize: compact ? 11 : 14,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: compact ? 20 : 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
