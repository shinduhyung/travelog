import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../data/geo_data.dart';

/// matches/{matchId} — Cloud Functions(socialCreateDuel 등)만 쓴다.
/// v2: 두 사람이 동시에 푸는 실시간 대결. v1(각자 풀고 보내기) 문서도 읽을 수 있게 변환한다.
class Duel {
  const Duel({
    required this.id,
    required this.players,
    required this.createdBy,
    required this.status,
    this.mode = 'mixed',
    this.difficulty = 'medium',
    this.scoring = 'speed',
    required this.questions,
    this.rounds = const {},
    this.scores = const {},
    this.round = 0,
    this.roundStartMs,
    this.roundEndsMs,
    this.timeLimitMs = 12000,
    this.winner,
    this.forfeitBy,
    this.abandoned = false,
    this.createdMs,
    this.finishedMs,
    this.legacy = false,
  });

  final String id;
  final List<String> players;
  final String createdBy;

  /// invited | playing | finished | declined | cancelled | expired
  final String status;
  final String mode;
  final String difficulty;
  final String scoring; // first | speed
  final List<DuelQuestion> questions;
  final Map<int, DuelRound> rounds;
  final Map<String, int> scores;
  final int round;
  final int? roundStartMs;
  final int? roundEndsMs;
  final int timeLimitMs;
  final String? winner; // finished인데 null이면 무승부
  final String? forfeitBy;
  final bool abandoned;
  final int? createdMs;
  final int? finishedMs;
  final bool legacy;

  static const inviteTtlMs = 10 * 60 * 1000;

  bool get isFinished => status == 'finished';
  bool get isInvite => status == 'invited';
  bool get isPlaying => status == 'playing';
  bool get isClosed => !isFinished && !isInvite && !isPlaying; // 거절/취소/만료

  bool inviteOpen(int nowMs) => isInvite && nowMs - (createdMs ?? 0) < inviteTtlMs;

  /// 진행 중인데 아무도 없어서 버려진 대결 (다음 tick에서 서버가 끝낸다)
  bool isStale(int nowMs) => isPlaying && (roundEndsMs ?? 0) + 60000 < nowMs;

  /// 목록에서 보여줄 시각
  DateTime? get createdAt => createdMs == null ? null : DateTime.fromMillisecondsSinceEpoch(createdMs!);

  String opponentOf(String uid) => players.firstWhere((p) => p != uid, orElse: () => uid);

  int scoreOf(String uid) => scores[uid] ?? 0;

  DuelRound roundAt(int i) => rounds[i] ?? const DuelRound();

  factory Duel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) => Duel.fromMap(doc.id, doc.data() ?? const {});

  factory Duel.fromMap(String id, Map<String, dynamic> d) {
    final players = (d['players'] as List? ?? const []).map((e) => e.toString()).toList();
    final questions = (d['questions'] as List? ?? const []).whereType<Map>().map(DuelQuestion.fromMap).toList();
    final mode = d['mode']?.toString() ?? d['game']?.toString() ?? 'flag';
    if (d['v'] != 2) return _fromV1(id, d, players, questions, mode);

    final rawRounds = (d['rounds'] as Map?) ?? const {};
    return Duel(
      id: id,
      players: players,
      createdBy: d['createdBy']?.toString() ?? '',
      status: d['status']?.toString() ?? 'invited',
      mode: mode,
      difficulty: d['difficulty']?.toString() ?? 'medium',
      scoring: d['scoring']?.toString() ?? 'speed',
      questions: questions,
      rounds: {
        for (final e in rawRounds.entries)
          if (int.tryParse(e.key.toString()) != null && e.value is Map) int.parse(e.key.toString()): DuelRound.fromMap(e.value as Map),
      },
      scores: {for (final e in ((d['scores'] as Map?) ?? const {}).entries) e.key.toString(): (e.value as num?)?.toInt() ?? 0},
      round: (d['round'] as num?)?.toInt() ?? 0,
      roundStartMs: (d['roundStartMs'] as num?)?.toInt(),
      roundEndsMs: (d['roundEndsMs'] as num?)?.toInt(),
      timeLimitMs: (d['timeLimitMs'] as num?)?.toInt() ?? 12000,
      winner: d['winner']?.toString(),
      forfeitBy: d['forfeitBy']?.toString(),
      abandoned: d['abandoned'] == true,
      createdMs: (d['createdMs'] as num?)?.toInt() ?? (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
      finishedMs: (d['finishedMs'] as num?)?.toInt(),
    );
  }

  /// v1: {results: {uid: {correct, elapsedMs, picks}}, answers} → 같은 모양으로
  static Duel _fromV1(String id, Map<String, dynamic> d, List<String> players, List<DuelQuestion> questions, String mode) {
    final results = (d['results'] as Map?) ?? const {};
    final answers = (d['answers'] as List?)?.map((e) => (e as num).toInt()).toList();
    final finished = d['status'] == 'finished';
    final rounds = <int, DuelRound>{};
    if (answers != null) {
      for (var i = 0; i < answers.length; i++) {
        final picks = <String, DuelPick>{};
        for (final e in results.entries) {
          final p = (e.value is Map ? (e.value as Map)['picks'] as List? : null);
          if (p == null || i >= p.length) continue;
          final c = (p[i] as num?)?.toInt() ?? -1;
          picks[e.key.toString()] = DuelPick(choice: c, ms: 0, ok: c == answers[i], points: c == answers[i] ? 1 : 0);
        }
        rounds[i] = DuelRound(answer: answers[i], picks: picks, answered: picks.keys.toSet(), closedMs: 1);
      }
    }
    return Duel(
      id: id,
      players: players,
      createdBy: d['createdBy']?.toString() ?? '',
      status: finished ? 'finished' : 'expired',
      mode: mode,
      scoring: 'first',
      questions: questions,
      rounds: rounds,
      scores: {
        for (final e in results.entries)
          if (e.value is Map) e.key.toString(): ((e.value as Map)['correct'] as num?)?.toInt() ?? 0,
      },
      round: questions.length,
      winner: d['winner']?.toString(),
      createdMs: (d['createdAt'] as Timestamp?)?.millisecondsSinceEpoch,
      legacy: true,
    );
  }
}

class DuelRound {
  const DuelRound({this.answered = const {}, this.picks = const {}, this.answer, this.detail, this.closedMs});

  final Set<String> answered;
  final Map<String, DuelPick> picks; // 라운드가 끝난 뒤에만 채워진다
  final int? answer;
  final List<String>? detail; // 보기별 실제 값 (km, 인구 등)
  final int? closedMs;

  bool get closed => closedMs != null;

  factory DuelRound.fromMap(Map raw) => DuelRound(
    answered: {
      for (final e in ((raw['answered'] as Map?) ?? const {}).entries)
        if (e.value == true) e.key.toString(),
    },
    picks: {
      for (final e in ((raw['picks'] as Map?) ?? const {}).entries)
        if (e.value is Map) e.key.toString(): DuelPick.fromMap(e.value as Map),
    },
    answer: (raw['answer'] as num?)?.toInt(),
    detail: (raw['detail'] as List?)?.map((e) => e.toString()).toList(),
    closedMs: (raw['closedMs'] as num?)?.toInt(),
  );
}

class DuelPick {
  const DuelPick({required this.choice, required this.ms, required this.ok, required this.points});

  final int choice; // -1 = 시간 초과/무효
  final int ms;
  final bool ok;
  final int points;

  factory DuelPick.fromMap(Map raw) => DuelPick(
    choice: (raw['c'] as num?)?.toInt() ?? -1,
    ms: (raw['ms'] as num?)?.toInt() ?? 0,
    ok: raw['ok'] == true,
    points: (raw['pts'] as num?)?.toInt() ?? 0,
  );
}

class DuelQuestion {
  const DuelQuestion({required this.type, required this.prompt, this.flag, this.image, this.subject, required this.choices});

  final String type; // flag | capital | population | area | landmark | city | farther
  final String prompt;
  final String? flag; // 문제에 크게 보여줄 국기 (ISO alpha-2), farther는 출발 도시의 나라
  final String? image; // 랜드마크 사진 URL
  final String? subject; // 문제 대상 이름 (랜드마크, 도시, 출발 도시)
  final List<DuelChoice> choices;

  factory DuelQuestion.fromMap(Map raw) {
    final rawChoices = raw['choices'] as List? ?? const [];
    // v1(국기만): {flag, choices: ["KR", ...]}
    if (rawChoices.isNotEmpty && rawChoices.first is String) {
      return DuelQuestion(
        type: 'flag',
        prompt: 'Which country is this flag?',
        flag: raw['flag']?.toString(),
        choices: [for (final c in rawChoices) DuelChoice(label: GeoData.I.countryByIso2(c.toString())?.name ?? c.toString())],
      );
    }
    return DuelQuestion(
      type: raw['type']?.toString() ?? 'flag',
      prompt: raw['prompt']?.toString() ?? '',
      flag: raw['flag']?.toString(),
      image: raw['image']?.toString(),
      subject: raw['subject']?.toString(),
      choices: [
        for (final c in rawChoices)
          if (c is Map) DuelChoice.fromMap(c),
      ],
    );
  }
}

class DuelChoice {
  const DuelChoice({required this.label, this.flag});

  final String label;
  final String? flag;

  factory DuelChoice.fromMap(Map raw) => DuelChoice(label: raw['label']?.toString() ?? '', flag: raw['flag']?.toString());
}

class DuelMode {
  const DuelMode(this.title, this.subtitle, this.icon, this.color);

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const duelModes = <String, DuelMode>{
  'mixed': DuelMode('Random mix', 'A bit of everything', Icons.shuffle_rounded, Color(0xFFC8566F)),
  'flag': DuelMode('Flags', 'Name the country', Icons.flag_rounded, Color(0xFFFF5A5F)),
  'capital': DuelMode('Capitals', 'Name the capital', Icons.account_balance_rounded, Color(0xFF6366F1)),
  'landmark': DuelMode('Landmarks', 'Guess from a photo', Icons.photo_camera_rounded, Color(0xFFFF9F1C)),
  'city': DuelMode('Cities', 'Find the country', Icons.location_city_rounded, Color(0xFF3E63DD)),
  'farther': DuelMode('Which is farther?', 'Compare distances', Icons.near_me_rounded, Color(0xFF2FBE73)),
  'population': DuelMode('Population', 'Most people wins', Icons.groups_rounded, Color(0xFF8B5CF6)),
  'area': DuelMode('Area', 'Largest country', Icons.public_rounded, Color(0xFF0EA5E9)),
};

DuelMode duelModeOf(String key) => duelModes[key] ?? duelModes['mixed']!;

/// Travelog 게임과 같은 난이도 이름/색
class DuelDifficulty {
  const DuelDifficulty(this.label, this.color, this.seconds);

  final String label;
  final Color color;
  final int seconds;
}

const duelDifficulties = <String, DuelDifficulty>{
  'easy': DuelDifficulty('Easy', Color(0xFF2FBE73), 15),
  'medium': DuelDifficulty('Medium', Color(0xFFFF9F1C), 12),
  'hard': DuelDifficulty('Hard', Color(0xFFFF5A5F), 10),
  'insane': DuelDifficulty('Insane', Color(0xFF3E63DD), 8),
};

DuelDifficulty duelDifficultyOf(String key) => duelDifficulties[key] ?? duelDifficulties['medium']!;

const duelScorings = <String, (String, String, IconData)>{
  'speed': ('Speed points', 'Correct answers score up to 1000. Faster = more.', Icons.bolt_rounded),
  'first': ('First to answer', 'First correct answer takes the round: 1 point.', Icons.sports_score_rounded),
};
