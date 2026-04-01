import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../application/game_providers.dart';
import '../../application/game_session_state.dart';
import '../puzzle_board_stage.dart';
import '../widgets/how_to_play_dialog.dart';
import '../widgets/music_settings_button.dart';

class GameScreen extends ConsumerWidget {
  const GameScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(gameSessionControllerProvider);
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final backgroundMusic = ref.read(backgroundMusicControllerProvider);
    final showGameOverOverlay =
        state.phase == GamePhase.resolving && state.runEndReason != null;
    final activateFever = !state.isInteractionLocked && state.canActivateFever
        ? controller.activateFever
        : null;
    final showHowToPlay =
        state.phase == GamePhase.playing && !state.isInteractionLocked
        ? () => _showHowToPlayDialog(context, ref)
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
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: _TopRightActions(
                              compact: true,
                              onShowHowToPlay: showHowToPlay,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _HudSection(state: state, compact: true),
                          const SizedBox(height: 10),
                          Expanded(
                            child: Center(
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: PuzzleBoardStage(state: state),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _ControlPanel(compact: true),
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
                          child: _TopRightActions(
                            onShowHowToPlay: showHowToPlay,
                          ),
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
                        const _ControlPanel(compact: false),
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
          Positioned.fill(
            child: IgnorePointer(
              child: _FeverStartBanner(active: state.isFeverActive),
            ),
          ),
          if (showGameOverOverlay)
            Positioned.fill(
              child: _GameOverOverlay(reason: state.runEndReason!),
            ),
        ],
      ),
    );
  }

  Future<void> _showHowToPlayDialog(BuildContext context, WidgetRef ref) async {
    final controller = ref.read(gameSessionControllerProvider.notifier);
    final paused = controller.pauseGame();
    try {
      await showDialog<void>(
        context: context,
        useSafeArea: false,
        builder: (_) => const HowToPlayDialog(showStartButton: false),
      );
    } finally {
      if (paused) {
        controller.resumeGame();
      }
    }
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
      ],
    );
  }
}

class _TopRightActions extends StatelessWidget {
  const _TopRightActions({required this.onShowHowToPlay, this.compact = false});

  final Future<void> Function()? onShowHowToPlay;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filledTonal(
          onPressed: onShowHowToPlay == null
              ? null
              : () => unawaited(onShowHowToPlay!()),
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
}

class _ControlPanel extends StatelessWidget {
  const _ControlPanel({required this.compact});

  final bool compact;

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
          Text(
            'ドラッグで操作',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 14 : 15,
              color: const Color(0xFF4A5565),
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: compact ? 6 : 8),
          Text(
            compact
                ? '牌を横に動かすと列、縦に動かすと行をスライドできます。'
                : '牌を直接ドラッグして操作します。横移動で列、縦移動で行が動き、無効な手はアニメーション後にもとへ戻ります。FEVER 中はどこを動かしても必ずそろいます。',
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

class _FeverDock extends StatelessWidget {
  const _FeverDock({required this.state, required this.onActivate});

  final GameSessionState state;
  final VoidCallback? onActivate;

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final buttonSize = shortestSide < 600 ? 84.0 : 96.0;
    final ringProgress = state.isFeverActive
        ? state.feverTimeProgress
        : state.feverGaugeProgress;
    final statusLabel = state.isFeverActive
        ? '${(state.feverRemainingMs / 1000).toStringAsFixed(1)}秒'
        : '${state.feverGauge} / ${state.feverChargeGoal}';
    final actionLabel = state.isFeverActive
        ? '${(state.feverRemainingMs / 1000).toStringAsFixed(1)}s'
        : state.canActivateFever
        ? 'GO'
        : 'CHARGE';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          key: const Key('fever_button'),
          width: buttonSize,
          height: buttonSize,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(
                painter: _FeverRingPainter(
                  progress: ringProgress,
                  active: state.isFeverActive,
                  ready: state.canActivateFever,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(7),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: state.isFeverActive
                            ? const [Color(0xFFFFB347), Color(0xFFFF6B6B)]
                            : state.canActivateFever
                            ? const [Color(0xFFF59E0B), Color(0xFFF97316)]
                            : const [Color(0xFF17324D), Color(0xFF0F766E)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              (state.isFeverActive
                                      ? const Color(0xFFF97316)
                                      : const Color(0xFF17324D))
                                  .withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: state.isFeverActive ? null : onActivate,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              state.isFeverActive ? 'FEVER!' : 'FEVER',
                              style: TextStyle(
                                fontSize: shortestSide < 600 ? 10 : 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              actionLabel,
                              style: TextStyle(
                                fontSize: shortestSide < 600 ? 10 : 11,
                                fontWeight: FontWeight.w800,
                                color: Colors.white.withValues(alpha: 0.94),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: buttonSize + 12,
          child: Text(
            statusLabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: shortestSide < 600 ? 11 : 12,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF314155),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeverRingPainter extends CustomPainter {
  const _FeverRingPainter({
    required this.progress,
    required this.active,
    required this.ready,
  });

  final double progress;
  final bool active;
  final bool ready;

  @override
  void paint(Canvas canvas, Size size) {
    final strokeWidth = size.width * 0.09;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(strokeWidth / 2);
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFCBD5E1).withValues(alpha: 0.45);

    canvas.drawArc(arcRect, 0, math.pi * 2, false, basePaint);

    if (progress <= 0) {
      return;
    }

    final progressPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: math.pi * 3 / 2,
        colors: active
            ? const [Color(0xFFFFF08A), Color(0xFFFF9A62), Color(0xFFFF6B6B)]
            : ready
            ? const [Color(0xFFFFF08A), Color(0xFFF59E0B), Color(0xFFF97316)]
            : const [Color(0xFFA7F3D0), Color(0xFF67E8F9), Color(0xFF2DD4BF)],
      ).createShader(rect);

    canvas.drawArc(
      arcRect,
      -math.pi / 2,
      math.pi * 2 * progress.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _FeverRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.active != active ||
        oldDelegate.ready != ready;
  }
}

class _FeverStartBanner extends StatefulWidget {
  const _FeverStartBanner({required this.active});

  final bool active;

  @override
  State<_FeverStartBanner> createState() => _FeverStartBannerState();
}

class _FeverStartBannerState extends State<_FeverStartBanner> {
  static const _displayDuration = Duration(milliseconds: 1450);

  Timer? _hideTimer;
  bool _visible = false;
  int _animationSeed = 0;

  @override
  void didUpdateWidget(covariant _FeverStartBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.active && widget.active) {
      _showBanner();
    }
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final compact = shortestSide < 600;
    final topPadding = compact ? 108.0 : 128.0;

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: topPadding),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (child, animation) {
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, -0.12),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          child: !_visible
              ? const SizedBox.shrink()
              : TweenAnimationBuilder<double>(
                  key: ValueKey(_animationSeed),
                  duration: _displayDuration,
                  tween: Tween(begin: 0, end: 1),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, child) {
                    final glow =
                        lerpDouble(
                          0.18,
                          0.32,
                          (1 - value).clamp(0.0, 0.6) / 0.6,
                        ) ??
                        0.24;
                    final scale =
                        lerpDouble(0.94, 1.0, value.clamp(0.0, 0.45) / 0.45) ??
                        1;
                    return Transform.scale(
                      scale: scale,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFFFF0A8),
                              Color(0xFFF59E0B),
                              Color(0xFFF97316),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(
                                0xFFF59E0B,
                              ).withValues(alpha: glow),
                              blurRadius: 28,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    constraints: BoxConstraints(maxWidth: compact ? 260 : 340),
                    padding: EdgeInsets.symmetric(
                      horizontal: compact ? 16 : 22,
                      vertical: compact ? 10 : 12,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'FEVER TIME',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.bungee(
                            fontSize: compact ? 20 : 26,
                            color: const Color(0xFF172033),
                            letterSpacing: 0.4,
                            shadows: [
                              Shadow(
                                color: Colors.white.withValues(alpha: 0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '今なら どこを動かしても そろう!',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: compact ? 11 : 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.1,
                            color: const Color(0xFF172033),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  void _showBanner() {
    _hideTimer?.cancel();
    setState(() {
      _visible = true;
      _animationSeed += 1;
    });
    _hideTimer = Timer(_displayDuration, () {
      if (!mounted) {
        return;
      }
      setState(() {
        _visible = false;
      });
    });
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
