import 'package:supabase_flutter/supabase_flutter.dart';

import 'leaderboard_entry.dart';

abstract class LeaderboardRepository {
  bool get isEnabled;

  Future<List<LeaderboardEntry>> fetchTop3();

  Future<int> fetchPlayerCount();

  Future<void> submitScore({required String playerName, required int score});
}

class DisabledLeaderboardRepository implements LeaderboardRepository {
  const DisabledLeaderboardRepository();

  @override
  bool get isEnabled => false;

  @override
  Future<List<LeaderboardEntry>> fetchTop3() async => const [];

  @override
  Future<int> fetchPlayerCount() async => 0;

  @override
  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {}
}

class InMemoryLeaderboardRepository implements LeaderboardRepository {
  InMemoryLeaderboardRepository({Map<String, int>? seedScores})
    : _scores = Map<String, int>.from(seedScores ?? const {});

  final Map<String, int> _scores;

  @override
  bool get isEnabled => true;

  @override
  Future<List<LeaderboardEntry>> fetchTop3() async => _rankedEntries();

  @override
  Future<int> fetchPlayerCount() async => _scores.length;

  @override
  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {
    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    final current = _scores[trimmedName];
    if (current == null || score > current) {
      _scores[trimmedName] = score;
    }
  }

  List<LeaderboardEntry> _rankedEntries() {
    final entries = _scores.entries.toList()
      ..sort((left, right) {
        final byScore = right.value.compareTo(left.value);
        if (byScore != 0) {
          return byScore;
        }
        return left.key.toLowerCase().compareTo(right.key.toLowerCase());
      });

    return [
      for (var index = 0; index < entries.length && index < 3; index += 1)
        LeaderboardEntry(
          rank: index + 1,
          playerName: entries[index].key,
          score: entries[index].value,
        ),
    ];
  }
}

class SupabaseLeaderboardRepository implements LeaderboardRepository {
  const SupabaseLeaderboardRepository(this._client);

  final SupabaseClient _client;

  @override
  bool get isEnabled => true;

  @override
  Future<List<LeaderboardEntry>> fetchTop3() async {
    final response = await _client.rpc<List<dynamic>>('get_leaderboard_top3');
    final rows = response;
    return rows
        .map((row) => _toEntry(_normalizeRow(row)))
        .toList(growable: false);
  }

  @override
  Future<int> fetchPlayerCount() async {
    final response = await _client.rpc<dynamic>('get_leaderboard_player_count');
    return _readInt(response);
  }

  @override
  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {
    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    await _client.rpc<dynamic>(
      'submit_leaderboard_score',
      params: {'p_player_name': trimmedName, 'p_score': score},
    );
  }

  LeaderboardEntry _toEntry(Map<String, dynamic> row) {
    return LeaderboardEntry(
      rank: _readInt(row['rank']),
      playerName: row['player_name'] as String? ?? '不明',
      score: _readInt(row['score']),
    );
  }

  Map<String, dynamic> _normalizeRow(dynamic row) {
    if (row is Map<String, dynamic>) {
      return row;
    }
    if (row is Map) {
      return row.map((key, value) => MapEntry('$key', value));
    }
    throw const FormatException('Unexpected leaderboard response row.');
  }

  int _readInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
