import '../domain/models.dart';

enum GamePhase { title, playing, resolving, result }

enum RunEndReason { noMoreMoves, timeUp }

const kInitialRunTimeMs = 30000;
const kHintDelayMs = 5000;

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
    required this.activeHint,
    required this.selectedRotationCenter,
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
      remainingRotations = kInitialRotationCharges,
      remainingTimeMs = kInitialRunTimeMs,
      activeHint = null,
      selectedRotationCenter = null,
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
  final BoardHint? activeHint;
  final BoardPosition? selectedRotationCenter;
  final bool inputLocked;
  final String? chainBanner;
  final RunEndReason? runEndReason;

  bool get hasBoard => board.isNotEmpty;

  GameSessionState copyWith({
    GamePhase? phase,
    BoardMatrix? board,
    int? score,
    int? bestScore,
    int? lastRunScore,
    int? currentChain,
    int? remainingRotations,
    int? remainingTimeMs,
    Object? activeHint = _unset,
    Object? selectedRotationCenter = _unset,
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
      activeHint: identical(activeHint, _unset)
          ? this.activeHint
          : activeHint as BoardHint?,
      selectedRotationCenter: identical(selectedRotationCenter, _unset)
          ? this.selectedRotationCenter
          : selectedRotationCenter as BoardPosition?,
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
