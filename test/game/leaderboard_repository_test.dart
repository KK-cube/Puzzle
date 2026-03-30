import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_1/game/domain/leaderboard_repository.dart';

void main() {
  test(
    'in-memory leaderboard keeps one row per play and allows duplicate names',
    () async {
      final repository = InMemoryLeaderboardRepository(
        seedSubmissions: const [
          LeaderboardSubmission(playerName: 'Alice', score: 100),
          LeaderboardSubmission(playerName: 'Alice', score: 260),
          LeaderboardSubmission(playerName: 'Bob', score: 240),
        ],
      );

      final entries = await repository.fetchTopEntries(limit: 10);

      expect(entries.map((entry) => entry.playerName), [
        'Alice',
        'Bob',
        'Alice',
      ]);
      expect(entries.map((entry) => entry.score), [260, 240, 100]);
      expect(await repository.fetchPlayerCount(), 3);
    },
  );

  test('in-memory leaderboard returns up to ten ranked plays', () async {
    final repository = InMemoryLeaderboardRepository(
      seedSubmissions: List.generate(
        12,
        (index) => LeaderboardSubmission(
          playerName: 'Player ${index + 1}',
          score: 1200 - (index * 10),
        ),
      ),
    );

    final entries = await repository.fetchTopEntries(limit: 10);

    expect(entries, hasLength(10));
    expect(entries.first.rank, 1);
    expect(entries.last.rank, 10);
    expect(entries.first.score, 1200);
    expect(entries.last.score, 1110);
  });
}
