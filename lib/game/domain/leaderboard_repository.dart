import 'package:supabase_flutter/supabase_flutter.dart';

import 'leaderboard_entry.dart';

abstract class LeaderboardRepository {
  bool get isEnabled;

  Future<List<LeaderboardEntry>> fetchTopEntries({int limit = 10});

  Future<int> fetchPlayerCount();

  Future<void> submitScore({required String playerName, required int score});
}

class DisabledLeaderboardRepository implements LeaderboardRepository {
  const DisabledLeaderboardRepository();

  @override
  bool get isEnabled => false;

  @override
  Future<List<LeaderboardEntry>> fetchTopEntries({int limit = 10}) async =>
      const [];

  @override
  Future<int> fetchPlayerCount() async => 0;

  @override
  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {}
}

class InMemoryLeaderboardRepository implements LeaderboardRepository {
  InMemoryLeaderboardRepository({
    Map<String, int>? seedScores,
    List<LeaderboardSubmission>? seedSubmissions,
  }) : _submissions = [] {
    for (final entry in (seedScores ?? const <String, int>{}).entries) {
      _submissions.add(
        _InMemorySubmission(
          playerName: entry.key,
          score: entry.value,
          sequence: _nextSequence++,
        ),
      );
    }
    for (final submission
        in seedSubmissions ?? const <LeaderboardSubmission>[]) {
      _submissions.add(
        _InMemorySubmission(
          playerName: submission.playerName,
          score: submission.score,
          sequence: _nextSequence++,
        ),
      );
    }
  }

  final List<_InMemorySubmission> _submissions;
  int _nextSequence = 0;

  @override
  bool get isEnabled => true;

  @override
  Future<List<LeaderboardEntry>> fetchTopEntries({int limit = 10}) async =>
      _rankedEntries(limit: limit);

  @override
  Future<int> fetchPlayerCount() async => _submissions.length;

  @override
  Future<void> submitScore({
    required String playerName,
    required int score,
  }) async {
    final trimmedName = playerName.trim();
    if (trimmedName.isEmpty) {
      return;
    }

    _submissions.add(
      _InMemorySubmission(
        playerName: trimmedName,
        score: score,
        sequence: _nextSequence++,
      ),
    );
  }

  List<LeaderboardEntry> _rankedEntries({required int limit}) {
    if (limit <= 0) {
      return const [];
    }

    final entries = List<_InMemorySubmission>.from(_submissions)
      ..sort((left, right) {
        final byScore = right.score.compareTo(left.score);
        if (byScore != 0) {
          return byScore;
        }
        final bySequence = left.sequence.compareTo(right.sequence);
        if (bySequence != 0) {
          return bySequence;
        }
        return left.playerName.toLowerCase().compareTo(
          right.playerName.toLowerCase(),
        );
      });

    return [
      for (var index = 0; index < entries.length && index < limit; index += 1)
        LeaderboardEntry(
          rank: index + 1,
          playerName: entries[index].playerName,
          score: entries[index].score,
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
  Future<List<LeaderboardEntry>> fetchTopEntries({int limit = 10}) async {
    final response = await _client.rpc<List<dynamic>>(
      'get_leaderboard',
      params: {'p_limit': limit},
    );
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

class LeaderboardSubmission {
  const LeaderboardSubmission({required this.playerName, required this.score});

  final String playerName;
  final int score;
}

class _InMemorySubmission {
  const _InMemorySubmission({
    required this.playerName,
    required this.score,
    required this.sequence,
  });

  final String playerName;
  final int score;
  final int sequence;
}
