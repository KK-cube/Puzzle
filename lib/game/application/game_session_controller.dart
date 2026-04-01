import 'dart:async';

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
    this.gameOverHold = const Duration(milliseconds: 1100),
    this.chainBannerHold = const Duration(milliseconds: 420),
    this.timerTick = const Duration(milliseconds: 100),
  });

  const GameSessionDurations.instant()
    : move = Duration.zero,
      revert = Duration.zero,
      clear = Duration.zero,
      settle = Duration.zero,
      gameOverHold = Duration.zero,
      chainBannerHold = Duration.zero,
      timerTick = const Duration(milliseconds: 100);

  final Duration move;
  final Duration revert;
  final Duration clear;
  final Duration settle;
  final Duration gameOverHold;
  final Duration chainBannerHold;
  final Duration timerTick;
}

class GameSessionController extends StateNotifier<GameSessionState> {
  GameSessionController({
    required PuzzleEngine engine,
    required HighScoreRepository highScoreRepository,
    required BoardAnimationBus animationBus,
    this.durations = const GameSessionDurations(),
  }) : _engine = engine,
       _highScoreRepository = highScoreRepository,
       _animationBus = animationBus,
       super(const GameSessionState.initial()) {
    unawaited(_loadBestScore());
  }

  final PuzzleEngine _engine;
  final HighScoreRepository _highScoreRepository;
  final BoardAnimationBus _animationBus;
  final GameSessionDurations durations;
  Timer? _countdownTimer;
  int _inactiveHintMs = 0;
  bool _timeUpPending = false;

  Future<void> _loadBestScore() async {
    final bestScore = await _highScoreRepository.loadHighScore();
    if (!mounted) {
      return;
    }

    state = state.copyWith(bestScore: bestScore);
  }

  void startNewGame() {
    _stopCountdown();
    _timeUpPending = false;
    final board = _engine.createInitialBoard(remainingRotations: 0);
    state = state.copyWith(
      phase: GamePhase.playing,
      board: board,
      score: 0,
      lastRunScore: 0,
      currentChain: 0,
      remainingRotations: 0,
      remainingTimeMs: kInitialRunTimeMs,
      feverGauge: 0,
      feverChargeGoal: kInitialFeverChargeGoal,
      feverRemainingMs: 0,
      activeHint: null,
      selectedRotationCenter: null,
      isPaused: false,
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
    _timeUpPending = false;
    state = state.copyWith(
      phase: GamePhase.title,
      feverGauge: 0,
      feverChargeGoal: kInitialFeverChargeGoal,
      feverRemainingMs: 0,
      remainingRotations: 0,
      isPaused: false,
      inputLocked: false,
      chainBanner: null,
      selectedRotationCenter: null,
      currentChain: 0,
      activeHint: null,
      runEndReason: null,
    );
  }

  void noteInteraction() {
    if (state.phase != GamePhase.playing || state.isPaused) {
      return;
    }

    _resetHintTimer(clearHint: true);
  }

  void selectRotationCenter(BoardPosition center) {
    if (state.isInteractionLocked || state.phase != GamePhase.playing) {
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
    if (state.isInteractionLocked ||
        state.remainingRotations <= 0 ||
        !state.hasBoard) {
      return;
    }

    final move = _bestRotationMove(direction: direction);
    if (move == null) {
      return;
    }

    await _runMove(move);
  }

  void activateFever() {
    if (state.phase != GamePhase.playing ||
        state.isInteractionLocked ||
        !state.canActivateFever) {
      return;
    }

    _resetHintTimer(clearHint: true);
    state = state.copyWith(
      feverGauge: 0,
      feverChargeGoal: state.feverChargeGoal + kFeverChargeGoalStep,
      feverRemainingMs: kFeverDurationMs,
      activeHint: null,
    );
  }

  bool pauseGame() {
    if (state.phase != GamePhase.playing ||
        state.inputLocked ||
        state.isPaused) {
      return false;
    }

    state = state.copyWith(isPaused: true);
    return true;
  }

  void resumeGame() {
    if (state.phase != GamePhase.playing || !state.isPaused) {
      return;
    }

    state = state.copyWith(isPaused: false);
  }

  Future<void> _runMove(MoveCommand move) async {
    if (state.phase != GamePhase.playing ||
        state.isInteractionLocked ||
        !state.hasBoard) {
      return;
    }

    _resetHintTimer(clearHint: true);

    final originalBoard = cloneBoard(state.board);
    final validation = _engine.validateMove(
      originalBoard,
      move,
      remainingRotations: state.remainingRotations,
      feverActive: state.isFeverActive,
    );
    final hasVisualChange = !boardsShareLayout(
      originalBoard,
      validation.previewBoard,
    );

    state = state.copyWith(
      phase: GamePhase.resolving,
      isPaused: false,
      inputLocked: true,
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

      if (_timeUpPending || state.remainingTimeMs <= 0) {
        await _finishRun(state.score, reason: RunEndReason.timeUp);
        return;
      }

      if (move.type == MoveType.rotate3x3 && state.remainingRotations <= 0) {
        state = state.copyWith(
          phase: GamePhase.playing,
          isPaused: false,
          inputLocked: false,
          selectedRotationCenter: null,
        );
      } else {
        state = state.copyWith(
          phase: GamePhase.playing,
          isPaused: false,
          inputLocked: false,
        );
      }
      return;
    }

    final application = _engine.applyMove(
      originalBoard,
      move,
      remainingRotations: state.remainingRotations,
      feverActive: state.isFeverActive,
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
          clearedPositions: wave.clearedPositions,
          chainIndex: wave.chainIndex,
          duration: durations.clear,
        ),
      );
      await Future<void>.delayed(durations.clear);

      nextScore += wave.scoreDelta;
      final timeBonusMs = _timeBonusForClearedTiles(wave.clearedTileIds.length);
      final feverGaugeGain = _feverGaugeGainForWave(wave.scoreDelta);
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        board: wave.boardAfterRefill,
        score: nextScore,
        currentChain: wave.chainIndex,
        remainingTimeMs: state.remainingTimeMs + timeBonusMs,
        feverGauge: state.isFeverActive
            ? state.feverGauge
            : (state.feverGauge + feverGaugeGain).clamp(
                0,
                state.feverChargeGoal,
              ),
        activeHint: null,
      );
      if (_timeUpPending && state.remainingTimeMs > 0) {
        _timeUpPending = false;
        _resumeCountdown();
      }
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

    if (_timeUpPending || state.remainingTimeMs <= 0) {
      await _finishRun(nextScore, reason: RunEndReason.timeUp);
      return;
    }

    final availableMoves = _engine.findAvailableMoves(
      state.board,
      remainingRotations: remainingRotations,
      feverActive: state.isFeverActive,
    );
    if (availableMoves.isEmpty) {
      await _finishRun(nextScore, reason: RunEndReason.noMoreMoves);
      return;
    }

    state = state.copyWith(
      phase: GamePhase.playing,
      isPaused: false,
      inputLocked: false,
      currentChain: 0,
      activeHint: null,
    );
    _resumeCountdown();
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(durations.timerTick, (_) => _tickTimer());
  }

  void _resumeCountdown() {
    if (_countdownTimer == null && !_timeUpPending) {
      _startCountdown();
    }
  }

  void _stopCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _tickTimer() {
    if (!mounted ||
        state.isPaused ||
        (state.phase != GamePhase.playing &&
            state.phase != GamePhase.resolving)) {
      return;
    }

    final elapsedMs = durations.timerTick.inMilliseconds;
    if (elapsedMs <= 0) {
      return;
    }

    final wasFeverActive = state.isFeverActive;
    if (wasFeverActive) {
      final nextFeverRemaining = (state.feverRemainingMs - elapsedMs).clamp(
        0,
        kFeverDurationMs,
      );
      if (nextFeverRemaining != state.feverRemainingMs) {
        state = state.copyWith(feverRemainingMs: nextFeverRemaining);
      }

      final feverJustEnded = nextFeverRemaining == 0;
      if (feverJustEnded &&
          state.phase == GamePhase.playing &&
          !state.isInteractionLocked &&
          state.hasBoard) {
        final availableMoves = _engine.findAvailableMoves(
          state.board,
          remainingRotations: state.remainingRotations,
        );
        if (availableMoves.isEmpty) {
          unawaited(_finishRun(state.score, reason: RunEndReason.noMoreMoves));
          return;
        }
      }
    }

    final nextRemainingTime = (state.remainingTimeMs - elapsedMs).clamp(
      0,
      1 << 31,
    );
    if (nextRemainingTime == state.remainingTimeMs) {
      return;
    }

    state = state.copyWith(remainingTimeMs: nextRemainingTime);
    if (nextRemainingTime <= 0) {
      if (state.phase == GamePhase.playing && !state.inputLocked) {
        unawaited(_finishRun(state.score, reason: RunEndReason.timeUp));
      } else {
        _timeUpPending = true;
        _stopCountdown();
      }
      return;
    }

    if (state.phase != GamePhase.playing || state.isInteractionLocked) {
      return;
    }

    _inactiveHintMs += elapsedMs;
    if (_inactiveHintMs >= kHintDelayMs && state.activeHint == null) {
      final hint = _buildHint();
      if (hint != null) {
        state = state.copyWith(activeHint: hint);
      }
    }
  }

  BoardHint? _buildHint() {
    final moves = _engine.findAvailableMoves(
      state.board,
      remainingRotations: state.remainingRotations,
      feverActive: state.isFeverActive,
    );
    if (moves.isEmpty) {
      return null;
    }

    if (moves.first.type == MoveType.rotate3x3) {
      final rotationHint = _bestRotationMove();
      if (rotationHint != null) {
        return BoardHint(move: rotationHint);
      }
    }

    return BoardHint(move: moves.first);
  }

  int _timeBonusForClearedTiles(int clearedTiles) {
    if (clearedTiles >= 4) {
      return 1500;
    }
    if (clearedTiles >= 3) {
      return 750;
    }
    return 0;
  }

  int _feverGaugeGainForWave(int scoreDelta) {
    return scoreDelta;
  }

  Future<void> _finishRun(int score, {required RunEndReason reason}) async {
    _stopCountdown();
    _timeUpPending = false;
    _resetHintTimer(clearHint: true);
    final finalBoard = cloneBoard(state.board);
    state = state.copyWith(
      phase: GamePhase.resolving,
      isPaused: false,
      inputLocked: true,
      remainingTimeMs: state.remainingTimeMs.clamp(0, kInitialRunTimeMs * 10),
      feverChargeGoal: state.feverChargeGoal,
      feverRemainingMs: 0,
      activeHint: null,
      selectedRotationCenter: null,
      runEndReason: reason,
    );
    _animationBus.emit(
      BoardAnimationEvent.gameOver(
        finalBoard,
        duration: durations.gameOverHold,
      ),
    );

    final bestScoreFuture = _highScoreRepository.saveIfHigher(score);
    if (durations.gameOverHold > Duration.zero) {
      await Future<void>.delayed(durations.gameOverHold);
    }
    final bestScore = await bestScoreFuture;
    if (!mounted) {
      return;
    }

    state = state.copyWith(
      phase: GamePhase.result,
      lastRunScore: score,
      bestScore: bestScore,
      isPaused: false,
      inputLocked: false,
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

  MoveCommand? _bestRotationMove({RotationDirection? direction}) {
    if (!state.hasBoard) {
      return null;
    }

    final candidates = _engine.findAvailableRotationMoves(
      state.board,
      remainingRotations: state.remainingRotations,
      direction: direction,
      feverActive: state.isFeverActive,
    );
    if (candidates.isEmpty) {
      return null;
    }

    MoveCommand? bestMove;
    var bestMatchedTiles = -1;
    for (final move in candidates) {
      final validation = _engine.validateMove(
        state.board,
        move,
        remainingRotations: state.remainingRotations,
        feverActive: state.isFeverActive,
      );
      if (!validation.isValid) {
        continue;
      }
      final matchedTiles = validation.matchedPositions.length;
      if (matchedTiles > bestMatchedTiles) {
        bestMove = move;
        bestMatchedTiles = matchedTiles;
      }
    }

    return bestMove;
  }

  @override
  void dispose() {
    _stopCountdown();
    super.dispose();
  }
}
