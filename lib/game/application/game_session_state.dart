import '../domain/models.dart';

enum GamePhase { title, playing, resolving, result }

enum RunEndReason { noMoreMoves, timeUp }

const kInitialRunTimeMs = 30000;
const kHintDelayMs = 5000;
const kFeverChargeGoals = <int>[500, 2500, 5000, 8000, 12000];
const kInitialFeverChargeGoal = 500;
const kFeverDurationMs = 7500;

int nextFeverChargeGoal(int currentGoal) {
  final currentIndex = kFeverChargeGoals.indexOf(currentGoal);
  if (currentIndex == -1 || currentIndex >= kFeverChargeGoals.length - 1) {
    return kFeverChargeGoals.last;
  }
  return kFeverChargeGoals[currentIndex + 1];
}

const _unset = Object();

class GameSessionState {
  const GameSessionState({
    required this.phase,
    required this.board,
    required this.score,
    required this.bestScore,
    required this.lastRunScore,
    required this.currentChain,
    required this.remainingRotations,
    required this.remainingTimeMs,
    required this.feverGauge,
    required this.feverChargeGoal,
    required this.feverRemainingMs,
    required this.activeHint,
    required this.selectedRotationCenter,
    required this.isPaused,
    required this.inputLocked,
    required this.chainBanner,
    required this.runEndReason,
  });

  const GameSessionState.initial()
    : phase = GamePhase.title,
      board = const [],
      score = 0,
      bestScore = 0,
      lastRunScore = 0,
      currentChain = 0,
      remainingRotations = 0,
      remainingTimeMs = kInitialRunTimeMs,
      feverGauge = 0,
      feverChargeGoal = kInitialFeverChargeGoal,
      feverRemainingMs = 0,
      activeHint = null,
      selectedRotationCenter = null,
      isPaused = false,
      inputLocked = false,
      chainBanner = null,
      runEndReason = null;

  final GamePhase phase;
  final BoardMatrix board;
  final int score;
  final int bestScore;
  final int lastRunScore;
  final int currentChain;
  final int remainingRotations;
  final int remainingTimeMs;
  final int feverGauge;
  final int feverChargeGoal;
  final int feverRemainingMs;
  final BoardHint? activeHint;
  final BoardPosition? selectedRotationCenter;
  final bool isPaused;
  final bool inputLocked;
  final String? chainBanner;
  final RunEndReason? runEndReason;

  bool get hasBoard => board.isNotEmpty;
  bool get isInteractionLocked => inputLocked || isPaused;
  bool get isFeverActive => feverRemainingMs > 0;
  bool get canActivateFever => !isFeverActive && feverGauge >= feverChargeGoal;
  double get feverGaugeProgress =>
      (feverGauge / feverChargeGoal).clamp(0.0, 1.0).toDouble();
  double get feverTimeProgress =>
      (feverRemainingMs / kFeverDurationMs).clamp(0.0, 1.0).toDouble();

  GameSessionState copyWith({
    GamePhase? phase,
    BoardMatrix? board,
    int? score,
    int? bestScore,
    int? lastRunScore,
    int? currentChain,
    int? remainingRotations,
    int? remainingTimeMs,
    int? feverGauge,
    int? feverChargeGoal,
    int? feverRemainingMs,
    Object? activeHint = _unset,
    Object? selectedRotationCenter = _unset,
    bool? isPaused,
    bool? inputLocked,
    Object? chainBanner = _unset,
    Object? runEndReason = _unset,
  }) {
    return GameSessionState(
      phase: phase ?? this.phase,
      board: board ?? this.board,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      lastRunScore: lastRunScore ?? this.lastRunScore,
      currentChain: currentChain ?? this.currentChain,
      remainingRotations: remainingRotations ?? this.remainingRotations,
      remainingTimeMs: remainingTimeMs ?? this.remainingTimeMs,
      feverGauge: feverGauge ?? this.feverGauge,
      feverChargeGoal: feverChargeGoal ?? this.feverChargeGoal,
      feverRemainingMs: feverRemainingMs ?? this.feverRemainingMs,
      activeHint: identical(activeHint, _unset)
          ? this.activeHint
          : activeHint as BoardHint?,
      selectedRotationCenter: identical(selectedRotationCenter, _unset)
          ? this.selectedRotationCenter
          : selectedRotationCenter as BoardPosition?,
      isPaused: isPaused ?? this.isPaused,
      inputLocked: inputLocked ?? this.inputLocked,
      chainBanner: identical(chainBanner, _unset)
          ? this.chainBanner
          : chainBanner as String?,
      runEndReason: identical(runEndReason, _unset)
          ? this.runEndReason
          : runEndReason as RunEndReason?,
    );
  }
}
