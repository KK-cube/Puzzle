import '../domain/models.dart';

enum GamePhase { title, playing, resolving, result }

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
    required this.selectedRotationCenter,
    required this.inputLocked,
    required this.chainBanner,
  });

  const GameSessionState.initial()
    : phase = GamePhase.title,
      board = const [],
      score = 0,
      bestScore = 0,
      lastRunScore = 0,
      currentChain = 0,
      remainingRotations = kInitialRotationCharges,
      selectedRotationCenter = null,
      inputLocked = false,
      chainBanner = null;

  final GamePhase phase;
  final BoardMatrix board;
  final int score;
  final int bestScore;
  final int lastRunScore;
  final int currentChain;
  final int remainingRotations;
  final BoardPosition? selectedRotationCenter;
  final bool inputLocked;
  final String? chainBanner;

  bool get hasBoard => board.isNotEmpty;

  GameSessionState copyWith({
    GamePhase? phase,
    BoardMatrix? board,
    int? score,
    int? bestScore,
    int? lastRunScore,
    int? currentChain,
    int? remainingRotations,
    Object? selectedRotationCenter = _unset,
    bool? inputLocked,
    Object? chainBanner = _unset,
  }) {
    return GameSessionState(
      phase: phase ?? this.phase,
      board: board ?? this.board,
      score: score ?? this.score,
      bestScore: bestScore ?? this.bestScore,
      lastRunScore: lastRunScore ?? this.lastRunScore,
      currentChain: currentChain ?? this.currentChain,
      remainingRotations: remainingRotations ?? this.remainingRotations,
      selectedRotationCenter: identical(selectedRotationCenter, _unset)
          ? this.selectedRotationCenter
          : selectedRotationCenter as BoardPosition?,
      inputLocked: inputLocked ?? this.inputLocked,
      chainBanner: identical(chainBanner, _unset)
          ? this.chainBanner
          : chainBanner as String?,
    );
  }
}
