import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/high_score_repository.dart';
import '../domain/models.dart';
import '../domain/puzzle_engine.dart';
import 'board_animation_bus.dart';
import 'game_session_state.dart';

class GameSessionController extends StateNotifier<GameSessionState> {
  GameSessionController({
    required PuzzleEngine engine,
    required HighScoreRepository highScoreRepository,
    required BoardAnimationBus animationBus,
  }) : _engine = engine,
       _highScoreRepository = highScoreRepository,
       _animationBus = animationBus,
       super(const GameSessionState.initial()) {
    unawaited(_loadBestScore());
  }

  static const _moveDuration = Duration(milliseconds: 220);
  static const _revertDuration = Duration(milliseconds: 180);
  static const _clearDuration = Duration(milliseconds: 200);
  static const _settleDuration = Duration(milliseconds: 260);
  static const _chainBannerHold = Duration(milliseconds: 420);

  final PuzzleEngine _engine;
  final HighScoreRepository _highScoreRepository;
  final BoardAnimationBus _animationBus;

  Future<void> _loadBestScore() async {
    final bestScore = await _highScoreRepository.loadHighScore();
    if (!mounted) {
      return;
    }

    state = state.copyWith(bestScore: bestScore);
  }

  void startNewGame() {
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
      selectedRotationCenter: null,
      inputLocked: false,
      chainBanner: null,
    );
    _animationBus.emit(BoardAnimationEvent.sync(board));
  }

  void returnToTitle() {
    state = state.copyWith(
      phase: GamePhase.title,
      inputLocked: false,
      chainBanner: null,
      selectedRotationCenter: null,
      currentChain: 0,
    );
  }

  void selectRotationCenter(BoardPosition center) {
    if (state.inputLocked || state.phase != GamePhase.playing) {
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
    final center = state.selectedRotationCenter;
    if (center == null) {
      return;
    }

    await _runMove(MoveCommand.rotate3x3(center: center, direction: direction));
  }

  Future<void> _runMove(MoveCommand move) async {
    if (state.phase != GamePhase.playing ||
        state.inputLocked ||
        !state.hasBoard) {
      return;
    }

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
          duration: _moveDuration,
        ),
      );
      await Future<void>.delayed(_moveDuration);
    }

    if (!validation.isValid) {
      if (hasVisualChange) {
        _animationBus.emit(
          BoardAnimationEvent.transition(
            originalBoard,
            duration: _revertDuration,
          ),
        );
        await Future<void>.delayed(_revertDuration);
      }

      if (!mounted) {
        return;
      }

      state = state.copyWith(phase: GamePhase.playing, inputLocked: false);
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
      selectedRotationCenter: null,
    );

    for (final wave in application.waves) {
      _animationBus.emit(
        BoardAnimationEvent.clear(
          wave.boardBeforeClear,
          clearedTileIds: wave.clearedTileIds,
          duration: _clearDuration,
        ),
      );
      if (wave.chainIndex > 1) {
        state = state.copyWith(
          chainBanner: '${wave.chainIndex} Chain',
          currentChain: wave.chainIndex,
        );
      }
      await Future<void>.delayed(_clearDuration);

      nextScore += wave.scoreDelta;
      if (!mounted) {
        return;
      }

      state = state.copyWith(
        board: wave.boardAfterRefill,
        score: nextScore,
        currentChain: wave.chainIndex,
      );
      _animationBus.emit(
        BoardAnimationEvent.transition(
          wave.boardAfterRefill,
          duration: _settleDuration,
          spawnFromTop: true,
        ),
      );
      await Future<void>.delayed(_settleDuration);
    }

    if (!mounted) {
      return;
    }

    if (state.chainBanner != null) {
      await Future<void>.delayed(_chainBannerHold);
      if (!mounted) {
        return;
      }
    }

    final availableMoves = _engine.findAvailableMoves(
      state.board,
      remainingRotations: remainingRotations,
    );
    if (availableMoves.isEmpty) {
      await _finishRun(nextScore);
      return;
    }

    state = state.copyWith(
      phase: GamePhase.playing,
      inputLocked: false,
      chainBanner: null,
      currentChain: 0,
    );
  }

  Future<void> _finishRun(int score) async {
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
      selectedRotationCenter: null,
    );
  }
}
