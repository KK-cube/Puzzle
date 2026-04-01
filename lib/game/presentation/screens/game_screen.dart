import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/game_providers.dart';
import '../../application/game_session_state.dart';
import '../../domain/models.dart';
import '../puzzle_board_stage.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/music_settings_button.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final engine = ref.watch(puzzleEngineProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);
    final showGameOverOverlay =
        state.phase == GamePhase.resolving && state.runEndReason != null;
    final rotationMoves = state.hasBoard
        ? engine.findAvailableRotationMoves(
            state.board,
            remainingRotations: state.remainingRotations,
          )
        : const <MoveCommand>[];
    final rotateCounterClockwise =
        _canRotate(state, rotationMoves, RotationDirection.counterClockwise)
        ? () => controller.rotateSelection(RotationDirection.counterClockwise)
        : null;
    final rotateClockwise =
        _canRotate(state, rotationMoves, RotationDirection.clockwise)
        ? () => controller.rotateSelection(RotationDirection.clockwise)
        : null;
    final activateFever = !state.inputLocked && state.canActivateFever
        ? controller.activateFever
        : null;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => unawaited(backgroundMusic.ensurePlaying()),
      child: Stack(
        children: [
          DecoratedBox(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFEF3C7),
                  Color(0xFFF2F7F1),
                  Color(0xFFDDEBFF),
                ],
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: _TopRightActions(compact: true),
                          ),
                          const SizedBox(height: 8),
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
                        Align(
                          alignment: Alignment.centerRight,
                          child: _TopRightActions(),
                        ),
                        const SizedBox(height: 12),
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
          ),
          Positioned(
            right: 16 + MediaQuery.paddingOf(context).right,
            bottom: 18 + MediaQuery.paddingOf(context).bottom,
            child: _FeverDock(state: state, onActivate: activateFever),
          ),
          if (showGameOverOverlay)
            Positioned.fill(
              child: _GameOverOverlay(reason: state.runEndReason!),
            ),
        ],
      ),
    );
  }

  bool _canRotate(
    GameSessionState state,
    List<MoveCommand> rotationMoves,
    RotationDirection direction,
  ) {
    return !state.inputLocked &&
        state.remainingRotations > 0 &&
        rotationMoves.any((move) => move.direction == direction);
  }

  static String _formatTime(int milliseconds) {
    final seconds = milliseconds / 1000;
    return '${seconds.toStringAsFixed(1)}秒';
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
          Expanded(child: _ScoreHudChip(score: state.score, compact: true)),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: '最高',
              value: '${state.bestScore}',
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: '時間',
              value: GameScreen._formatTime(state.remainingTimeMs),
              compact: true,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _HudChip(
              label: '回転',
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
        _ScoreHudChip(score: state.score),
        _HudChip(label: '最高', value: '${state.bestScore}'),
        _HudChip(
          label: '時間',
          value: GameScreen._formatTime(state.remainingTimeMs),
        ),
        _HudChip(label: '残り回転', value: '${state.remainingRotations}'),
      ],
    );
  }
}

class _TopRightActions extends StatelessWidget {
  const _TopRightActions({this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: () => _showHowToPlayDialog(context),
          tooltip: '操作方法',
          icon: Icon(Icons.help_outline_rounded, size: compact ? 20 : 22),
          style: IconButton.styleFrom(
            visualDensity: compact
                ? VisualDensity.compact
                : VisualDensity.standard,
          ),
        ),
        const SizedBox(width: 8),
        MusicSettingsButton(compact: compact),
      ],
    );
  }

  Future<void> _showHowToPlayDialog(BuildContext context) {
    return showDialog<void>(
      context: context,
      useSafeArea: false,
      builder: (_) => const HowToPlayDialog(showStartButton: false),
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
          if (compact)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRotateCounterClockwise,
                    icon: const Icon(Icons.rotate_left_rounded),
                    label: const Text('左回転'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onRotateClockwise,
                    icon: const Icon(Icons.rotate_right_rounded),
                    label: const Text('右回転'),
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
                  label: const Text('左回転'),
                ),
                FilledButton.icon(
                  onPressed: onRotateClockwise,
                  icon: const Icon(Icons.rotate_right_rounded),
                  label: const Text('右回転'),
                ),
              ],
            ),
          SizedBox(height: compact ? 8 : 10),
          Text(
            _rotationMessage(),
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
                ? '牌を横に動かすと列、縦に動かすと行をスライドできます。'
                : '牌を直接ドラッグして操作します。横移動で列、縦移動で行が動き、無効な手はアニメーション後にもとへ戻ります。',
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

  String _rotationMessage() {
    if (state.remainingRotations <= 0) {
      return 'このプレイではもう回転できません。';
    }
    return '回転は通常時でも使えます。押せる向きでは、必ず 3 マス以上そろう 3x3 回転だけが発動します。';
  }
}

class _FeverDock extends StatelessWidget {
  const _FeverDock({required this.state, required this.onActivate});

  final GameSessionState state;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final meterProgress = state.isFeverActive
        ? state.feverTimeProgress
        : state.feverGaugeProgress;
    final statusLabel = state.isFeverActive
        ? '${(state.feverRemainingMs / 1000).toStringAsFixed(1)}s'
        : '${state.feverGauge} / $kFeverGaugeMax';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: 132,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: state.isFeverActive
              ? const [Color(0xFFFFB347), Color(0xFFFF6B6B), Color(0xFFFFD166)]
              : const [Color(0xFF17324D), Color(0xFF0F766E)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color:
                (state.isFeverActive
                        ? const Color(0xFFF97316)
                        : const Color(0xFF17324D))
                    .withValues(alpha: 0.24),
            blurRadius: 24,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            state.isFeverActive ? 'FEVER!' : 'FEVER',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.4,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 10,
              child: Stack(
                children: [
                  Container(color: Colors.white.withValues(alpha: 0.18)),
                  FractionallySizedBox(
                    widthFactor: meterProgress,
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFF08A), Color(0xFFFF9A62)],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.92),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: state.isFeverActive ? null : onActivate,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF172033),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.22),
                disabledForegroundColor: Colors.white.withValues(alpha: 0.88),
                padding: const EdgeInsets.symmetric(vertical: 10),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: Text(
                state.isFeverActive
                    ? '発動中'
                    : state.canActivateFever
                    ? '発動'
                    : 'ためる',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ScoreHudChip extends StatefulWidget {
  const _ScoreHudChip({required this.score, this.compact = false});

  final int score;
  final bool compact;

  @override
  State<_ScoreHudChip> createState() => _ScoreHudChipState();
}

class _ScoreHudChipState extends State<_ScoreHudChip> {
  static const _burstDuration = Duration(milliseconds: 900);

  Timer? _clearTimer;
  int? _delta;
  int _burstSeed = 0;

  @override
  void didUpdateWidget(covariant _ScoreHudChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    final delta = widget.score - oldWidget.score;
    if (delta <= 0) {
      return;
    }

    _clearTimer?.cancel();
    setState(() {
      _delta = delta;
      _burstSeed += 1;
    });
    _clearTimer = Timer(_burstDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _delta = null;
      });
    });
  }

  @override
  void dispose() {
    _clearTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        _HudChip(
          label: '得点',
          value: '${widget.score}',
          compact: widget.compact,
        ),
        if (_delta != null)
          Positioned(
            top: widget.compact ? -16 : -20,
            right: widget.compact ? 10 : 14,
            child: _ScoreBurst(
              key: ValueKey(_burstSeed),
              delta: _delta!,
              compact: widget.compact,
            ),
          ),
      ],
    );
  }
}

class _ScoreBurst extends StatelessWidget {
  const _ScoreBurst({super.key, required this.delta, required this.compact});

  final int delta;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 860),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      builder: (context, value, child) {
        final opacity = value < 0.72 ? 1.0 : 1 - ((value - 0.72) / 0.28);
        final lift = lerpDouble(12, -10, value) ?? 0;
        final scale =
            lerpDouble(0.88, 1.02, value.clamp(0.0, 0.45) / 0.45) ?? 1;
        return Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, lift),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 4 : 5,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFFF59E0B),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.28),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Text(
          '+$delta',
          style: TextStyle(
            fontSize: compact ? 12 : 14,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF172033),
          ),
        ),
      ),
    );
  }
}

class _GameOverOverlay extends StatelessWidget {
  const _GameOverOverlay({required this.reason});

  final RunEndReason reason;

  @override
  Widget build(BuildContext context) {
    final title = switch (reason) {
      RunEndReason.timeUp => 'TIME UP',
      RunEndReason.noMoreMoves => 'NO MOVES',
    };
    final subtitle = switch (reason) {
      RunEndReason.timeUp => '残り時間が尽きました',
      RunEndReason.noMoreMoves => '次の一手が見つかりません',
    };

    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 780),
        curve: Curves.easeOutCubic,
        tween: Tween(begin: 0, end: 1),
        builder: (context, value, child) {
          final opacity = value.clamp(0.0, 1.0);
          final scale = lerpDouble(0.92, 1.0, value) ?? 1.0;
          final slide = lerpDouble(24, 0, value) ?? 0;
          return DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A).withValues(alpha: opacity * 0.24),
            ),
            child: Center(
              child: Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, slide),
                  child: Transform.scale(scale: scale, child: child),
                ),
              ),
            ),
          );
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 28),
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFE7ECF3)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F172A).withValues(alpha: 0.16),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.2,
                  color: Color(0xFF172033),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF556273),
                ),
              ),
            ],
          ),
        ),
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
