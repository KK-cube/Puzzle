import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/high_score_repository.dart';
import '../domain/models.dart';
import '../domain/puzzle_engine.dart';
import 'board_animation_bus.dart';
import 'game_session_state.dart';

class GameSessionDurations {
  const GameSessionDurations({
    this.move = const Duration(milliseconds: 220),
    this.revert = const Duration(milliseconds: 180),
    this.clear = const Duration(milliseconds: 200),
    this.settle = const Duration(milliseconds: 260),
    this.chainBannerHold = const Duration(milliseconds: 420),
    this.timerTick = const Duration(milliseconds: 100),
  });

  const GameSessionDurations.instant()
    : move = Duration.zero,
      revert = Duration.zero,
      clear = Duration.zero,
      settle = Duration.zero,
      chainBannerHold = Duration.zero,
      timerTick = const Duration(milliseconds: 100);

  final Duration move;
  final Duration revert;
  final Duration clear;
  final Duration settle;
  final Duration chainBannerHold;
  final Duration timerTick;
}

class GameSessionController extends StateNotifier<GameSessionState> {
  GameSessionController({
    required PuzzleEngine engine,
    required HighScoreRepository highScoreRepository,
    required BoardAnimationBus animationBus,
    Random? random,
    this.durations = const GameSessionDurations(),
  }) : _engine = engine,
       _highScoreRepository = highScoreRepository,
       _animationBus = animationBus,
       _random = random ?? Random(),
       super(const GameSessionState.initial()) {
    unawaited(_loadBestScore());
  }

  final PuzzleEngine _engine;
  final HighScoreRepository _highScoreRepository;
  final BoardAnimationBus _animationBus;
  final Random _random;
  final GameSessionDurations durations;
  Timer? _countdownTimer;
  int _inactiveHintMs = 0;

  Future<void> _loadBestScore() async {
    final bestScore = await _highScoreRepository.loadHighScore();
    if (!mounted) {
      return;
    }

    state = state.copyWith(bestScore: bestScore);
  }

  void startNewGame() {
    _stopCountdown();
    final board = _engine.createInitialBoard(
      remainingRotations: kInitialRotationCharges,
    );
    state = state.copyWith(
      phase: GamePhase.playing,
      board: board,
      score: 0,
      lastRunScore: 0,
      currentChain: 0,
      remainingRotations: kInitialRotationCharges,
      remainingTimeMs: kInitialRunTimeMs,
      activeHint: null,
      selectedRotationCenter: null,
      inputLocked: false,
      chainBanner: null,
      runEndReason: null,
    );
    _animationBus.emit(BoardAnimationEvent.sync(board));
    _resetHintTimer(clearHint: true);
    _startCountdown();
  }

  void returnToTitle() {
    _stopCountdown();
    state = state.copyWith(
      phase: GamePhase.title,
      inputLocked: false,
      chainBanner: null,
      selectedRotationCenter: null,
      currentChain: 0,
      activeHint: null,
      runEndReason: null,
    );
  }

  void noteInteraction() {
    if (state.phase != GamePhase.playing) {
      return;
    }

    _resetHintTimer(clearHint: true);
  }

  void selectRotationCenter(BoardPosition center) {
    if (state.inputLocked || state.phase != GamePhase.playing) {
      return;
    }

    if (state.remainingRotations <= 0) {
      clearRotationSelection();
      return;
    }

    if (!center.isRotationCenter) {
      clearRotationSelection();
      return;
    }

    final current = state.selectedRotationCenter;
    state = state.copyWith(
      selectedRotationCenter: current == center ? null : center,
    );
  }

  void clearRotationSelection() {
    if (state.selectedRotationCenter == null) {
      return;
    }

    state = state.copyWith(selectedRotationCenter: null);
  }

  Future<void> swapRows(int fromRow, int toRow) async {
    await _runMove(MoveCommand.swapRows(fromRow, toRow));
  }

  Future<void> swapColumns(int fromColumn, int toColumn) async {
    await _runMove(MoveCommand.swapColumns(fromColumn, toColumn));
  }

  Future<void> rotateSelection(RotationDirection direction) async {
    if (state.remainingRotations <= 0) {
      return;
    }

    await _runMove(
      MoveCommand.rotate3x3(
        center: _randomRotationCenter(),
        direction: direction,
      ),
    );
  }

  Future<void> _runMove(MoveCommand move) async {
    if (state.phase != GamePhase.playing ||
        state.inputLocked ||
        !state.hasBoard) {
      return;
    }

    _resetHintTimer(clearHint: true);

    final originalBoard = cloneBoard(state.board);
    final validation = _engine.validateMove(
      originalBoard,
      move,
      remainingRotations: state.remainingRotations,
    );
    final hasVisualChange = !boardsShareLayout(
      originalBoard,
      validation.previewBoard,
    );

    state = state.copyWith(
      phase: GamePhase.resolving,
      inputLocked: true,
      chainBanner: null,
      currentChain: 0,
    );

    if (hasVisualChange) {
      _animationBus.emit(
        BoardAnimationEvent.transition(
          validation.previewBoard,
          duration: durations.move,
        ),
      );
      await Future<void>.delayed(durations.move);
    }

    if (!validation.isValid) {
      if (hasVisualChange) {
        _animationBus.emit(
          BoardAnimationEvent.transition(
            originalBoard,
            duration: durations.revert,
          ),
        );
        await Future<void>.delayed(durations.revert);
      }

      if (!mounted) {
        return;
      }

      if (move.type == MoveType.rotate3x3 && state.remainingRotations <= 0) {
        state = state.copyWith(
          phase: GamePhase.playing,
          inputLocked: false,
          selectedRotationCenter: null,
        );
      } else {
        state = state.copyWith(phase: GamePhase.playing, inputLocked: false);
      }
      return;
    }

    final application = _engine.applyMove(
      originalBoard,
      move,
      remainingRotations: state.remainingRotations,
    );
    var nextScore = state.score;
    var remainingRotations = state.remainingRotations;
    if (application.consumesRotation) {
      remainingRotations -= 1;
    }

    state = state.copyWith(
      board: application.previewBoard,
      remainingRotations: remainingRotations,
      activeHint: null,
      selectedRotationCenter: null,
    );

    for (final wave in application.waves) {
      _animationBus.emit(
        BoardAnimationEvent.clear(
          wave.boardBeforeClear,
          clearedTileIds: wave.clearedTileIds,
          duration: durations.clear,
        ),
      );
      if (wave.chainIndex > 1) {
        state = state.copyWith(
          chainBanner: '${wave.chainIndex}連鎖',
          currentChain: wave.chainIndex,
        );
      }
      await Future<void>.delayed(durations.clear);

      nextScore += wave.scoreDelta;
      final timeBonusMs = _timeBonusForClearedTiles(wave.clearedTileIds.length);
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        board: wave.boardAfterRefill,
        score: nextScore,
        currentChain: wave.chainIndex,
        remainingTimeMs: state.remainingTimeMs + timeBonusMs,
        activeHint: null,
      );
      _animationBus.emit(
        BoardAnimationEvent.transition(
          wave.boardAfterRefill,
          duration: durations.settle,
          spawnFromTop: true,
        ),
      );
      await Future<void>.delayed(durations.settle);
    }

    if (!mounted) {
      return;
    }

    if (state.chainBanner != null) {
      await Future<void>.delayed(durations.chainBannerHold);
      if (!mounted) {
        return;
      }
    }

    final availableMoves = _engine.findAvailableMoves(
      state.board,
      remainingRotations: remainingRotations,
    );
    if (availableMoves.isEmpty) {
      await _finishRun(nextScore, reason: RunEndReason.noMoreMoves);
      return;
    }

    state = state.copyWith(
      phase: GamePhase.playing,
      inputLocked: false,
      chainBanner: null,
      currentChain: 0,
      activeHint: null,
    );
    _resumeCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(durations.timerTick, (_) => _tickTimer());
  }

  void _resumeCountdown() {}

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _tickTimer() {
    if (!mounted || state.phase != GamePhase.playing || state.inputLocked) {
      return;
    }

    final elapsedMs = durations.timerTick.inMilliseconds;
    if (elapsedMs <= 0) {
      return;
    }

    final nextRemainingTime = (state.remainingTimeMs - elapsedMs).clamp(
      0,
      1 << 31,
    );
    if (nextRemainingTime == state.remainingTimeMs) {
      return;
    }

    state = state.copyWith(remainingTimeMs: nextRemainingTime);
    _inactiveHintMs += elapsedMs;
    if (_inactiveHintMs >= kHintDelayMs && state.activeHint == null) {
      final hint = _buildHint();
      if (hint != null) {
        state = state.copyWith(activeHint: hint);
      }
    }
    if (nextRemainingTime <= 0) {
      unawaited(_finishRun(state.score, reason: RunEndReason.timeUp));
    }
  }

  BoardHint? _buildHint() {
    final moves = _engine.findAvailableMoves(
      state.board,
      remainingRotations: state.remainingRotations,
    );
    if (moves.isEmpty) {
      return null;
    }

    return BoardHint(move: moves.first);
  }

  BoardPosition _randomRotationCenter() {
    final row = 1 + _random.nextInt(kBoardSize - 2);
    final column = 1 + _random.nextInt(kBoardSize - 2);
    return BoardPosition(row, column);
  }

  int _timeBonusForClearedTiles(int clearedTiles) {
    if (clearedTiles >= 4) {
      return 1000;
    }
    if (clearedTiles >= 3) {
      return 500;
    }
    return 0;
  }

  Future<void> _finishRun(int score, {required RunEndReason reason}) async {
    _stopCountdown();
    _resetHintTimer(clearHint: true);
    state = state.copyWith(
      phase: GamePhase.resolving,
      inputLocked: true,
      remainingTimeMs: state.remainingTimeMs.clamp(0, kInitialRunTimeMs * 10),
    );
    final bestScore = await _highScoreRepository.saveIfHigher(score);
    if (!mounted) {
      return;
    }

    state = state.copyWith(
      phase: GamePhase.result,
      lastRunScore: score,
      bestScore: bestScore,
      inputLocked: false,
      chainBanner: null,
      currentChain: 0,
      remainingTimeMs: state.remainingTimeMs,
      activeHint: null,
      selectedRotationCenter: null,
      runEndReason: reason,
    );
  }

  void _resetHintTimer({required bool clearHint}) {
    _inactiveHintMs = 0;
    if (clearHint && state.activeHint != null) {
      state = state.copyWith(activeHint: null);
    }
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }
}
