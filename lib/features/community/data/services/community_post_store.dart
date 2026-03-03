import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';

/// A posted bracket-picks entry in the BMB Community.
class CommunityBracketPost {
  final String id;
  final String userId;
  final String userName;
  final String bracketId;
  final String bracketName;
  final String sport;
  final String bracketType;
  final int totalPicks;
  final int correct;
  final int wrong;
  final int pending;
  final String? championPick;
  final int? tieBreakerPrediction;
  final String summary; // full picks text
  final String message; // casual auto-post language
  final DateTime postedAt;

  // Bracket tree data for visual rendering
  final List<String>? teams; // original team list
  final Map<String, String>? picksMap; // gameId -> picked team
  final int? totalRounds;

  const CommunityBracketPost({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bracketId,
    required this.bracketName,
    required this.sport,
    required this.bracketType,
    required this.totalPicks,
    required this.correct,
    required this.wrong,
    required this.pending,
    this.championPick,
    this.tieBreakerPrediction,
    required this.summary,
    required this.message,
    required this.postedAt,
    this.teams,
    this.picksMap,
    this.totalRounds,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'userId': userId,
    'userName': userName,
    'bracketId': bracketId,
    'bracketName': bracketName,
    'sport': sport,
    'bracketType': bracketType,
    'totalPicks': totalPicks,
    'correct': correct,
    'wrong': wrong,
    'pending': pending,
    'championPick': championPick,
    'tieBreakerPrediction': tieBreakerPrediction,
    'summary': summary,
    'message': message,
    'postedAt': postedAt.toIso8601String(),
    'teams': teams,
    'picksMap': picksMap,
    'totalRounds': totalRounds,
  };

  factory CommunityBracketPost.fromJson(Map<String, dynamic> json) {
    return CommunityBracketPost(
      id: json['id'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String,
      bracketId: json['bracketId'] as String,
      bracketName: json['bracketName'] as String,
      sport: json['sport'] as String? ?? '',
      bracketType: json['bracketType'] as String? ?? '',
      totalPicks: json['totalPicks'] as int? ?? 0,
      correct: json['correct'] as int? ?? 0,
      wrong: json['wrong'] as int? ?? 0,
      pending: json['pending'] as int? ?? 0,
      championPick: json['championPick'] as String?,
      tieBreakerPrediction: json['tieBreakerPrediction'] as int?,
      summary: json['summary'] as String? ?? '',
      message: json['message'] as String? ?? '',
      postedAt: DateTime.tryParse(json['postedAt'] as String? ?? '') ?? DateTime.now(),
      teams: (json['teams'] as List<dynamic>?)?.map((e) => e as String).toList(),
      picksMap: (json['picksMap'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
      totalRounds: json['totalRounds'] as int?,
    );
  }
}

/// Singleton store for community bracket posts.
/// Persists via SharedPreferences so posts survive navigation & app restart.
class CommunityPostStore {
  static final CommunityPostStore _instance = CommunityPostStore._();
  factory CommunityPostStore() => _instance;
  CommunityPostStore._();

  static const _prefsKey = 'community_bracket_posts';
  final List<CommunityBracketPost> _posts = [];
  bool _loaded = false;

  List<CommunityBracketPost> get posts => List.unmodifiable(_posts);

  /// Generate a casual, fun auto-post message.
  static String generateAutoPostMessage({
    required String bracketName,
    String? championPick,
  }) {
    final rng = Random();
    final messages = [
      "Hey take a look at my picks, y'all. What ya think?",
      "Just locked in my picks! Check 'em out and let me know what you think.",
      "Alright fam, my picks are IN. Think I got a shot?",
      "Yo who else is in this bracket? Check out my picks!",
      "My bracket picks are LIVE. Roast me or gas me up, let's go!",
      "Just submitted my picks - feeling good about this one! Thoughts?",
      "Picks are locked and loaded! Am I crazy or am I onto something?",
      "Posted my picks for the squad. Agree or disagree?",
    ];

    String msg = messages[rng.nextInt(messages.length)];

    if (championPick != null) {
      final champPhrases = [
        " I'm riding with $championPick all the way!",
        " Got $championPick winning it all.",
        " $championPick is my champ. Fight me.",
        " Taking $championPick to cut down the nets!",
      ];
      msg += champPhrases[rng.nextInt(champPhrases.length)];
    }

    return msg;
  }

  /// Load posts from disk.
  Future<void> init() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_prefsKey);
    if (raw != null) {
      for (final jsonStr in raw) {
        try {
          final map = jsonDecode(jsonStr) as Map<String, dynamic>;
          _posts.add(CommunityBracketPost.fromJson(map));
        } catch (_) {
          // skip corrupt entries
        }
      }
    }
    _loaded = true;
  }

  /// Add a new bracket post and persist.
  Future<void> addPost(CommunityBracketPost post) async {
    _posts.add(post);
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = _posts.map((p) => jsonEncode(p.toJson())).toList();
    await prefs.setStringList(_prefsKey, raw);
  }
}
