import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bmb_mobile/core/services/current_user_service.dart';

/// Difficulty levels for trivia questions.
enum TriviaDifficulty { easy, medium, hard }

/// Single trivia question with 4 choices, one correct answer, and a difficulty.
class TriviaQuestion {
  final String question;
  final List<String> choices; // always 4
  final int correctIndex; // 0-3
  final String category; // e.g. 'NBA', 'NFL', 'NCAA', 'MLB', 'General', 'NHL'
  final String explanation;
  final TriviaDifficulty difficulty;

  const TriviaQuestion({
    required this.question,
    required this.choices,
    required this.correctIndex,
    required this.category,
    required this.explanation,
    this.difficulty = TriviaDifficulty.medium,
  });

  String get correctAnswer => choices[correctIndex];

  /// Time allowed in seconds based on difficulty.
  /// Easy = 15s, Medium = 12s, Hard = 10s
  int get timeLimit {
    switch (difficulty) {
      case TriviaDifficulty.easy:
        return 15;
      case TriviaDifficulty.medium:
        return 12;
      case TriviaDifficulty.hard:
        return 10;
    }
  }

  /// Base credits earned for correct answer (before streak bonus).
  /// Easy = 1, Medium = 2, Hard = 3
  int get baseCredits {
    switch (difficulty) {
      case TriviaDifficulty.easy:
        return 1;
      case TriviaDifficulty.medium:
        return 2;
      case TriviaDifficulty.hard:
        return 3;
    }
  }
}

/// Tracks a player's trivia stats.
class TriviaPlayerStats {
  final String playerId;
  final String playerName;
  final int totalCorrect;
  final int totalAnswered;
  final int currentStreak;
  final int bestStreak;
  final int creditsEarned;

  const TriviaPlayerStats({
    required this.playerId,
    required this.playerName,
    this.totalCorrect = 0,
    this.totalAnswered = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.creditsEarned = 0,
  });

  double get accuracy =>
      totalAnswered > 0 ? (totalCorrect / totalAnswered) * 100 : 0;
}

/// Service that generates daily trivia, tracks streaks, awards credits,
/// and maintains a leaderboard.
///
/// Anti-cheat: each question has a countdown timer based on difficulty.
/// If the timer expires, the question is marked wrong (streak broken).
///
/// Credits system:
///   - Easy correct: 1 credit
///   - Medium correct: 2 credits
///   - Hard correct: 3 credits
///   - 10-streak bonus: +5 bonus credits
///   - Speed bonus: answer in <50% time = +1 extra credit
///   - Timer expired = wrong answer (0 credits, streak reset)
///
/// Persistence: uses SharedPreferences so progress survives app restarts.
class TriviaService {
  // ──────────────────────────────────────────────────────────────────────
  // Singleton
  // ──────────────────────────────────────────────────────────────────────
  static final TriviaService _instance = TriviaService._();
  factory TriviaService() => _instance;
  TriviaService._();

  // ──────────────────────────────────────────────────────────────────────
  // Constants
  // ──────────────────────────────────────────────────────────────────────
  /// Maximum number of **correct** answers per day that earn credits.
  /// After this limit the user can still play for fun, but no credits
  /// are awarded and they see a "come back tomorrow" notice.
  static const int dailyCorrectLimit = 3;

  // ──────────────────────────────────────────────────────────────────────
  // State
  // ──────────────────────────────────────────────────────────────────────
  List<TriviaQuestion> _todayQuestions = [];
  String _lastGeneratedDate = '';

  int _currentStreak = 0;
  int _bestStreak = 0;
  int _totalCorrect = 0;
  int _totalAnswered = 0;
  int _creditsEarned = 0;
  int _todayAnswered = 0;
  int _todayCreditsEarned = 0;
  int _todayCorrectCount = 0; // correct answers today (for daily limit)
  final Set<int> _todayCorrectIndices = {};

  // Last answer result details
  int _lastCreditsAwarded = 0;
  bool _lastWasSpeedBonus = false;
  bool _lastWasStreakBonus = false;
  bool _lastTimedOut = false;

  final List<TriviaPlayerStats> _leaderboard = [];

  // ──────────────────────────────────────────────────────────────────────
  // Public getters
  // ──────────────────────────────────────────────────────────────────────
  int get currentStreak => _currentStreak;
  int get bestStreak => _bestStreak;
  int get totalCorrect => _totalCorrect;
  int get totalAnswered => _totalAnswered;
  int get creditsEarned => _creditsEarned;
  int get todayAnswered => _todayAnswered;
  int get todayTotal => _todayQuestions.length;
  int get todayCreditsEarned => _todayCreditsEarned;
  int get todayCorrectCount => _todayCorrectCount;
  bool get dailyLimitReached => _todayCorrectCount >= dailyCorrectLimit;
  int get dailyCorrectRemaining => (dailyCorrectLimit - _todayCorrectCount).clamp(0, dailyCorrectLimit);
  List<TriviaQuestion> get todayQuestions => _todayQuestions;
  List<TriviaPlayerStats> get leaderboard => List.unmodifiable(_leaderboard);

  int get lastCreditsAwarded => _lastCreditsAwarded;
  bool get lastWasSpeedBonus => _lastWasSpeedBonus;
  bool get lastWasStreakBonus => _lastWasStreakBonus;
  bool get lastTimedOut => _lastTimedOut;

  /// Streak bonus: every 10 correct in a row = +5 bonus credits.
  bool get streakRewardPending => _currentStreak > 0 && _currentStreak % 10 == 0;

  /// Returns the next unanswered question index, or -1 if done for today.
  int get nextQuestionIndex {
    for (int i = 0; i < _todayQuestions.length; i++) {
      if (!_todayCorrectIndices.contains(i) && i >= _todayAnswered) return i;
    }
    return -1;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Init
  // ──────────────────────────────────────────────────────────────────────
  Future<void> init() async {
    await _loadProgress();
    _ensureTodayQuestions();
    _seedLeaderboard();
  }

  // ──────────────────────────────────────────────────────────────────────
  // Answer a question (with time tracking for anti-cheat)
  // timeRemainingSeconds: how many seconds were LEFT on the countdown
  //   - if 0, the timer expired → auto-wrong
  // ──────────────────────────────────────────────────────────────────────
  Future<bool> answerQuestion(
    int questionIndex,
    int choiceIndex, {
    int timeRemainingSeconds = -1, // -1 means no timer (legacy)
  }) async {
    if (questionIndex < 0 || questionIndex >= _todayQuestions.length) {
      return false;
    }
    final q = _todayQuestions[questionIndex];

    // Reset last-answer tracking
    _lastCreditsAwarded = 0;
    _lastWasSpeedBonus = false;
    _lastWasStreakBonus = false;
    _lastTimedOut = false;

    _totalAnswered++;
    _todayAnswered = questionIndex + 1;

    // Timer expired → wrong answer
    if (timeRemainingSeconds == 0) {
      _lastTimedOut = true;
      _currentStreak = 0;
      await _saveProgress();
      _updateLeaderboard();
      return false;
    }

    final correct = choiceIndex == q.correctIndex;

    if (correct) {
      _totalCorrect++;
      _currentStreak++;
      _todayCorrectCount++;
      _todayCorrectIndices.add(questionIndex);
      if (_currentStreak > _bestStreak) _bestStreak = _currentStreak;

      // ── Daily limit check: only award credits within the limit ──
      if (_todayCorrectCount <= dailyCorrectLimit) {
        // Award credits
        int credits = q.baseCredits;

        // Speed bonus: answered in less than 50% of the allotted time
        if (timeRemainingSeconds > 0) {
          final halfTime = q.timeLimit / 2;
          final timeUsed = q.timeLimit - timeRemainingSeconds;
          if (timeUsed <= halfTime) {
            credits += 1; // speed bonus
            _lastWasSpeedBonus = true;
          }
        }

        // Streak bonus: every 10 correct in a row → +5
        if (_currentStreak % 10 == 0) {
          credits += 5;
          _lastWasStreakBonus = true;
        }

        _lastCreditsAwarded = credits;
        _creditsEarned += credits;
        _todayCreditsEarned += credits;

        // Also update SharedPreferences BMB balance
        await _addToBmbBalance(credits);
      }
      // If over limit, no credits awarded (lastCreditsAwarded stays 0)
    } else {
      _currentStreak = 0; // streak broken
    }

    await _saveProgress();
    _updateLeaderboard();
    return correct;
  }

  // ──────────────────────────────────────────────────────────────────────
  // BMB Bucket Balance Integration
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _addToBmbBalance(int credits) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getDouble('bmb_bucks_balance') ?? 0.0;
    await prefs.setDouble('bmb_bucks_balance', current + credits.toDouble());
  }

  // ──────────────────────────────────────────────────────────────────────
  // Daily question generation (mixed difficulties)
  // ──────────────────────────────────────────────────────────────────────
  void _ensureTodayQuestions() {
    final today = _todayKey();
    if (_lastGeneratedDate == today && _todayQuestions.isNotEmpty) return;

    _lastGeneratedDate = today;
    _todayAnswered = 0;
    _todayCreditsEarned = 0;
    _todayCorrectCount = 0;
    _todayCorrectIndices.clear();
    _todayQuestions = _generateDailyQuestions(today);
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Deterministically generate 10 questions per day from a large pool,
  /// balanced across difficulties: 3 Easy, 4 Medium, 3 Hard.
  List<TriviaQuestion> _generateDailyQuestions(String dateKey) {
    final seed = dateKey.hashCode;
    final rng = Random(seed);

    final easyPool = _questionPool.where((q) => q.difficulty == TriviaDifficulty.easy).toList()..shuffle(rng);
    final medPool = _questionPool.where((q) => q.difficulty == TriviaDifficulty.medium).toList()..shuffle(rng);
    final hardPool = _questionPool.where((q) => q.difficulty == TriviaDifficulty.hard).toList()..shuffle(rng);

    final selected = <TriviaQuestion>[];
    selected.addAll(easyPool.take(3));
    selected.addAll(medPool.take(4));
    selected.addAll(hardPool.take(3));

    // Shuffle the final set so difficulties are mixed
    selected.shuffle(rng);
    return selected;
  }

  // ──────────────────────────────────────────────────────────────────────
  // Persistence
  // ──────────────────────────────────────────────────────────────────────
  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    _currentStreak = prefs.getInt('trivia_streak') ?? 0;
    _bestStreak = prefs.getInt('trivia_best_streak') ?? 0;
    _totalCorrect = prefs.getInt('trivia_total_correct') ?? 0;
    _totalAnswered = prefs.getInt('trivia_total_answered') ?? 0;
    _creditsEarned = prefs.getInt('trivia_credits_earned') ?? 0;
    _lastGeneratedDate = prefs.getString('trivia_last_date') ?? '';
    _todayAnswered = prefs.getInt('trivia_today_answered') ?? 0;
    _todayCreditsEarned = prefs.getInt('trivia_today_credits') ?? 0;
    _todayCorrectCount = prefs.getInt('trivia_today_correct_count') ?? 0;
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('trivia_streak', _currentStreak);
    await prefs.setInt('trivia_best_streak', _bestStreak);
    await prefs.setInt('trivia_total_correct', _totalCorrect);
    await prefs.setInt('trivia_total_answered', _totalAnswered);
    await prefs.setInt('trivia_credits_earned', _creditsEarned);
    await prefs.setString('trivia_last_date', _lastGeneratedDate);
    await prefs.setInt('trivia_today_answered', _todayAnswered);
    await prefs.setInt('trivia_today_credits', _todayCreditsEarned);
    await prefs.setInt('trivia_today_correct_count', _todayCorrectCount);
  }

  // ──────────────────────────────────────────────────────────────────────
  // Leaderboard
  // ──────────────────────────────────────────────────────────────────────
  void _seedLeaderboard() {
    _leaderboard.clear();
    _leaderboard.addAll([
      const TriviaPlayerStats(playerId: 'bot_stats', playerName: 'StatGuru42', totalCorrect: 312, totalAnswered: 350, currentStreak: 22, bestStreak: 45, creditsEarned: 580),
      const TriviaPlayerStats(playerId: 'bot_swish', playerName: 'SwishKing', totalCorrect: 289, totalAnswered: 340, currentStreak: 14, bestStreak: 31, creditsEarned: 490),
      const TriviaPlayerStats(playerId: 'bot_cindy', playerName: 'CinderellaFan', totalCorrect: 267, totalAnswered: 310, currentStreak: 8, bestStreak: 28, creditsEarned: 430),
      const TriviaPlayerStats(playerId: 'bot_jam81', playerName: 'JamSession81', totalCorrect: 245, totalAnswered: 300, currentStreak: 3, bestStreak: 19, creditsEarned: 380),
      const TriviaPlayerStats(playerId: 'bot_madness', playerName: 'MarchMadnessMax', totalCorrect: 230, totalAnswered: 280, currentStreak: 11, bestStreak: 22, creditsEarned: 350),
      const TriviaPlayerStats(playerId: 'bot_chalky', playerName: 'ChalkMaster', totalCorrect: 198, totalAnswered: 260, currentStreak: 5, bestStreak: 16, creditsEarned: 290),
    ]);
    _updateLeaderboard();
  }

  void _updateLeaderboard() {
    final cuId = CurrentUserService.instance.userId;
    final cuName = CurrentUserService.instance.displayName.isNotEmpty ? CurrentUserService.instance.displayName : 'BracketKing';
    _leaderboard.removeWhere((p) => CurrentUserService.instance.isCurrentUser(p.playerId));
    _leaderboard.add(TriviaPlayerStats(
      playerId: cuId,
      playerName: cuName,
      totalCorrect: _totalCorrect,
      totalAnswered: _totalAnswered,
      currentStreak: _currentStreak,
      bestStreak: _bestStreak,
      creditsEarned: _creditsEarned,
    ));
    _leaderboard.sort((a, b) => b.totalCorrect.compareTo(a.totalCorrect));
  }

  // ──────────────────────────────────────────────────────────────────────
  // 75+ question pool with Easy / Medium / Hard difficulty
  // ──────────────────────────────────────────────────────────────────────
  static const List<TriviaQuestion> _questionPool = [
    // ════════════════════════════════════════════════════════════════════
    // EASY questions (15s timer, 1 credit)
    // ════════════════════════════════════════════════════════════════════

    // NBA Easy
    TriviaQuestion(question: 'How many players per team are on a basketball court?', choices: ['4', '5', '6', '7'], correctIndex: 1, category: 'NBA', explanation: 'Each basketball team has 5 players on the court.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What shape is a basketball?', choices: ['Oval', 'Sphere', 'Cylinder', 'Cube'], correctIndex: 1, category: 'NBA', explanation: 'A basketball is a sphere.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many points is a free throw worth?', choices: ['1', '2', '3', '4'], correctIndex: 0, category: 'NBA', explanation: 'A free throw is worth 1 point.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What color is a regulation NBA basketball?', choices: ['White', 'Orange', 'Brown', 'Red'], correctIndex: 1, category: 'NBA', explanation: 'NBA basketballs are orange with black seams.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many points is a shot from behind the arc worth?', choices: ['1', '2', '3', '4'], correctIndex: 2, category: 'NBA', explanation: 'A shot beyond the three-point line is worth 3 points.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What is the NBA All-Star Game?', choices: ['A charity event', 'An exhibition game of top players', 'A playoff game', 'A draft event'], correctIndex: 1, category: 'NBA', explanation: 'The NBA All-Star Game features the best players voted in by fans, media, and players.', difficulty: TriviaDifficulty.easy),

    // NFL Easy
    TriviaQuestion(question: 'How many points is a field goal worth in the NFL?', choices: ['1', '2', '3', '6'], correctIndex: 2, category: 'NFL', explanation: 'A field goal is worth 3 points.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What is the biggest annual NFL event called?', choices: ['World Series', 'The Finals', 'Super Bowl', 'Playoffs'], correctIndex: 2, category: 'NFL', explanation: 'The Super Bowl is the NFL championship game.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many points is a touchdown worth?', choices: ['3', '5', '6', '7'], correctIndex: 2, category: 'NFL', explanation: 'A touchdown is 6 points plus a PAT attempt.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What shape is an American football?', choices: ['Round', 'Prolate spheroid (oval)', 'Square', 'Flat disc'], correctIndex: 1, category: 'NFL', explanation: 'An American football is a prolate spheroid.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many quarters are in an NFL game?', choices: ['2', '3', '4', '5'], correctIndex: 2, category: 'NFL', explanation: 'An NFL game has 4 quarters.', difficulty: TriviaDifficulty.easy),

    // NCAA Easy
    TriviaQuestion(question: 'What does NCAA stand for?', choices: ['National College Athletic Association', 'National Collegiate Athletic Association', 'National Championship Athletics Association', 'None of the above'], correctIndex: 1, category: 'NCAA', explanation: 'NCAA = National Collegiate Athletic Association.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'March Madness is associated with which sport?', choices: ['Football', 'Baseball', 'Basketball', 'Soccer'], correctIndex: 2, category: 'NCAA', explanation: 'March Madness is the NCAA basketball tournament.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many teams make the Final Four?', choices: ['2', '3', '4', '8'], correctIndex: 2, category: 'NCAA', explanation: 'The Final Four is the last 4 teams in March Madness.', difficulty: TriviaDifficulty.easy),

    // General Easy
    TriviaQuestion(question: 'How many rings are on the Olympic flag?', choices: ['3', '4', '5', '6'], correctIndex: 2, category: 'General', explanation: 'The Olympic flag has 5 rings representing 5 continents.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What sport is played at Wimbledon?', choices: ['Golf', 'Cricket', 'Tennis', 'Rugby'], correctIndex: 2, category: 'General', explanation: 'Wimbledon is the oldest tennis championship.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'In which sport do you use a bat and ball on a diamond?', choices: ['Cricket', 'Baseball', 'Golf', 'Tennis'], correctIndex: 1, category: 'General', explanation: 'Baseball is played on a diamond-shaped field.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What sport uses a shuttlecock?', choices: ['Tennis', 'Squash', 'Badminton', 'Table Tennis'], correctIndex: 2, category: 'General', explanation: 'Badminton uses a feathered shuttlecock.', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'What is the diameter of a basketball hoop in inches?', choices: ['16', '17', '18', '19'], correctIndex: 2, category: 'General', explanation: 'A basketball hoop is 18 inches in diameter.', difficulty: TriviaDifficulty.easy),

    // MLB Easy
    TriviaQuestion(question: 'How many bases are on a baseball diamond?', choices: ['2', '3', '4', '5'], correctIndex: 2, category: 'MLB', explanation: 'A baseball diamond has 4 bases (1st, 2nd, 3rd, home).', difficulty: TriviaDifficulty.easy),
    TriviaQuestion(question: 'How many strikes make an out in baseball?', choices: ['2', '3', '4', '5'], correctIndex: 1, category: 'MLB', explanation: '3 strikes and you are out!', difficulty: TriviaDifficulty.easy),

    // ════════════════════════════════════════════════════════════════════
    // MEDIUM questions (12s timer, 2 credits)
    // ════════════════════════════════════════════════════════════════════

    // NBA Medium
    TriviaQuestion(question: 'Which player has won the most NBA championships?', choices: ['Michael Jordan', 'Bill Russell', 'Kareem Abdul-Jabbar', 'LeBron James'], correctIndex: 1, category: 'NBA', explanation: 'Bill Russell won 11 NBA championships with the Boston Celtics.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Who holds the record for most points in a single NBA game?', choices: ['Kobe Bryant', 'Wilt Chamberlain', 'Michael Jordan', 'LeBron James'], correctIndex: 1, category: 'NBA', explanation: 'Wilt Chamberlain scored 100 points on March 2, 1962.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which NBA team has the most championships?', choices: ['Los Angeles Lakers', 'Chicago Bulls', 'Boston Celtics', 'Golden State Warriors'], correctIndex: 2, category: 'NBA', explanation: 'The Boston Celtics have won 17 NBA championships.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Who was the first overall pick in the 2003 NBA Draft?', choices: ['Carmelo Anthony', 'Chris Bosh', 'LeBron James', 'Dwyane Wade'], correctIndex: 2, category: 'NBA', explanation: 'LeBron James was drafted #1 by the Cleveland Cavaliers.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Who is the NBA\'s all-time leading scorer?', choices: ['Karl Malone', 'Kobe Bryant', 'Kareem Abdul-Jabbar', 'LeBron James'], correctIndex: 3, category: 'NBA', explanation: 'LeBron James surpassed Kareem Abdul-Jabbar in February 2023.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which player is known as "The Greek Freak"?', choices: ['Luka Doncic', 'Nikola Jokic', 'Giannis Antetokounmpo', 'Joel Embiid'], correctIndex: 2, category: 'NBA', explanation: 'Giannis Antetokounmpo of the Milwaukee Bucks.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'How many minutes are in an NBA regulation game?', choices: ['40 minutes', '44 minutes', '48 minutes', '52 minutes'], correctIndex: 2, category: 'NBA', explanation: 'An NBA game has 4 quarters of 12 minutes each.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which team did Kevin Durant play for before the Warriors?', choices: ['Houston Rockets', 'Oklahoma City Thunder', 'Brooklyn Nets', 'Seattle SuperSonics'], correctIndex: 1, category: 'NBA', explanation: 'KD played for OKC Thunder before joining Golden State in 2016.', difficulty: TriviaDifficulty.medium),

    // NFL Medium
    TriviaQuestion(question: 'Who holds the NFL record for most career passing yards?', choices: ['Peyton Manning', 'Drew Brees', 'Tom Brady', 'Aaron Rodgers'], correctIndex: 2, category: 'NFL', explanation: 'Tom Brady holds the record with 89,214 career passing yards.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What is the only NFL team to complete a perfect season?', choices: ['1985 Bears', '1972 Dolphins', '2007 Patriots', '1989 49ers'], correctIndex: 1, category: 'NFL', explanation: 'The 1972 Miami Dolphins went 17-0 including the Super Bowl.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What NFL team plays at Lambeau Field?', choices: ['Minnesota Vikings', 'Chicago Bears', 'Green Bay Packers', 'Detroit Lions'], correctIndex: 2, category: 'NFL', explanation: 'Lambeau Field is home to the Packers.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which NFL quarterback is known as "TB12"?', choices: ['Tony Romo', 'Tom Brady', 'Tim Tebow', 'Tua Tagovailoa'], correctIndex: 1, category: 'NFL', explanation: 'Tom Brady, #12, played for the Patriots and Buccaneers.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What is a "Hail Mary" in football?', choices: ['A field goal attempt', 'A long desperation pass', 'A trick play', 'A defensive formation'], correctIndex: 1, category: 'NFL', explanation: 'A Hail Mary is a very long forward pass with little time left.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Who was the NFL MVP in 2023?', choices: ['Patrick Mahomes', 'Lamar Jackson', 'Josh Allen', 'Jalen Hurts'], correctIndex: 1, category: 'NFL', explanation: 'Lamar Jackson of the Baltimore Ravens won the 2023 NFL MVP.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which team drafted Patrick Mahomes?', choices: ['Buffalo Bills', 'Kansas City Chiefs', 'Houston Texans', 'Cleveland Browns'], correctIndex: 1, category: 'NFL', explanation: 'The Chiefs traded up to draft Mahomes 10th overall in 2017.', difficulty: TriviaDifficulty.medium),

    // NCAA Medium
    TriviaQuestion(question: 'Which team has won the most NCAA Men\'s Basketball Championships?', choices: ['Duke', 'Kentucky', 'UCLA', 'North Carolina'], correctIndex: 2, category: 'NCAA', explanation: 'UCLA has won 11 NCAA championships, the most in history.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'How many teams compete in March Madness?', choices: ['32', '48', '64', '68'], correctIndex: 3, category: 'NCAA', explanation: '68 teams compete, including the First Four play-in games.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What is a "Cinderella" in March Madness?', choices: ['The championship trophy', 'A low-seeded team that overperforms', 'A halftime show', 'A mascot'], correctIndex: 1, category: 'NCAA', explanation: 'A Cinderella is an underdog team that advances far.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What year did the NCAA tournament expand to 64 teams?', choices: ['1975', '1985', '1995', '2005'], correctIndex: 1, category: 'NCAA', explanation: 'The tournament expanded to 64 teams in 1985.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which school won back-to-back NCAA titles in 2006 and 2007?', choices: ['Duke', 'UConn', 'Florida', 'Kansas'], correctIndex: 2, category: 'NCAA', explanation: 'The Florida Gators won back-to-back titles.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'In a 64-team single elimination bracket, how many games are played?', choices: ['32', '48', '63', '64'], correctIndex: 2, category: 'NCAA', explanation: '63 games: each game eliminates one team, and 63 must be eliminated.', difficulty: TriviaDifficulty.medium),

    // MLB Medium
    TriviaQuestion(question: 'Who holds the MLB record for most career home runs?', choices: ['Babe Ruth', 'Hank Aaron', 'Barry Bonds', 'Willie Mays'], correctIndex: 2, category: 'MLB', explanation: 'Barry Bonds hit 762 career home runs.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'Which MLB team has won the most World Series?', choices: ['St. Louis Cardinals', 'New York Yankees', 'Boston Red Sox', 'San Francisco Giants'], correctIndex: 1, category: 'MLB', explanation: 'The New York Yankees have won 27 World Series titles.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'How many innings are in a regulation MLB game?', choices: ['7', '8', '9', '10'], correctIndex: 2, category: 'MLB', explanation: 'A regulation MLB game is 9 innings.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What team broke the "Curse of the Bambino" in 2004?', choices: ['Chicago Cubs', 'Boston Red Sox', 'Cleveland Indians', 'New York Mets'], correctIndex: 1, category: 'MLB', explanation: 'The Red Sox won the 2004 World Series, ending an 86-year drought.', difficulty: TriviaDifficulty.medium),

    // General/NHL Medium
    TriviaQuestion(question: 'What is the NHL\'s championship trophy called?', choices: ['Lombardi Trophy', 'Commissioner\'s Trophy', 'Stanley Cup', 'Larry O\'Brien Trophy'], correctIndex: 2, category: 'NHL', explanation: 'The Stanley Cup is the oldest pro sports trophy in North America.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'How many periods are in a regulation NHL game?', choices: ['2', '3', '4', '5'], correctIndex: 1, category: 'NHL', explanation: 'An NHL game has 3 periods of 20 minutes each.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What country has won the most FIFA World Cup titles?', choices: ['Germany', 'Argentina', 'Italy', 'Brazil'], correctIndex: 3, category: 'General', explanation: 'Brazil has won the FIFA World Cup 5 times.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'In golf, what is one stroke under par called?', choices: ['Eagle', 'Birdie', 'Albatross', 'Bogey'], correctIndex: 1, category: 'General', explanation: 'A birdie is one stroke under par.', difficulty: TriviaDifficulty.medium),
    TriviaQuestion(question: 'What does "chalk" mean in bracket terminology?', choices: ['Using colored markers', 'Picking all favorites', 'Picking all upsets', 'A tiebreaker method'], correctIndex: 1, category: 'General', explanation: 'Going "chalk" means picking higher seeds to win every game.', difficulty: TriviaDifficulty.medium),

    // ════════════════════════════════════════════════════════════════════
    // HARD questions (10s timer, 3 credits)
    // ════════════════════════════════════════════════════════════════════

    // NBA Hard
    TriviaQuestion(question: 'What NBA team did Shaquille O\'Neal NOT play for?', choices: ['Orlando Magic', 'Los Angeles Lakers', 'Dallas Mavericks', 'Boston Celtics'], correctIndex: 2, category: 'NBA', explanation: 'Shaq never played for Dallas. He played for Orlando, LAL, Miami, Phoenix, Cleveland, and Boston.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'What year was the NBA founded?', choices: ['1936', '1946', '1956', '1966'], correctIndex: 1, category: 'NBA', explanation: 'The NBA was founded June 6, 1946, as the BAA.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Who was the youngest player to score 30,000 career NBA points?', choices: ['Michael Jordan', 'Kobe Bryant', 'LeBron James', 'Kareem Abdul-Jabbar'], correctIndex: 2, category: 'NBA', explanation: 'LeBron James reached 30,000 points at age 33 years, 24 days.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which NBA player has the most triple-doubles in history?', choices: ['Magic Johnson', 'LeBron James', 'Oscar Robertson', 'Russell Westbrook'], correctIndex: 3, category: 'NBA', explanation: 'Russell Westbrook holds the all-time record with 199 triple-doubles.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'What year did the NBA introduce the 3-point line?', choices: ['1975-76', '1979-80', '1983-84', '1987-88'], correctIndex: 1, category: 'NBA', explanation: 'The NBA added the 3-point line for the 1979-80 season.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which player scored 81 points in a single NBA game?', choices: ['Wilt Chamberlain', 'Kobe Bryant', 'Michael Jordan', 'David Robinson'], correctIndex: 1, category: 'NBA', explanation: 'Kobe Bryant scored 81 points vs Toronto on Jan 22, 2006, the 2nd highest ever.', difficulty: TriviaDifficulty.hard),

    // NFL Hard
    TriviaQuestion(question: 'Which team has won the most Super Bowls?', choices: ['Dallas Cowboys', 'San Francisco 49ers', 'New England Patriots', 'Pittsburgh Steelers'], correctIndex: 2, category: 'NFL', explanation: 'The Patriots and Steelers are tied with 6 each (as of 2024).', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Who holds the NFL single-season rushing record?', choices: ['Barry Sanders', 'Eric Dickerson', 'Adrian Peterson', 'Derrick Henry'], correctIndex: 1, category: 'NFL', explanation: 'Eric Dickerson rushed for 2,105 yards in 1984.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which quarterback has the most career touchdown passes?', choices: ['Peyton Manning', 'Drew Brees', 'Tom Brady', 'Brett Favre'], correctIndex: 2, category: 'NFL', explanation: 'Tom Brady threw 649 career touchdown passes.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'What year was the first Super Bowl played?', choices: ['1960', '1963', '1967', '1970'], correctIndex: 2, category: 'NFL', explanation: 'Super Bowl I was played on January 15, 1967.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Who has the most career interceptions in NFL history?', choices: ['Deion Sanders', 'Rod Woodson', 'Paul Krause', 'Charles Woodson'], correctIndex: 2, category: 'NFL', explanation: 'Paul Krause holds the record with 81 career interceptions.', difficulty: TriviaDifficulty.hard),

    // NCAA Hard
    TriviaQuestion(question: 'What was the first 16-seed to beat a 1-seed in March Madness?', choices: ['Norfolk State', 'UMBC', 'Fairleigh Dickinson', 'Florida Gulf Coast'], correctIndex: 1, category: 'NCAA', explanation: 'UMBC beat Virginia 74-54 in 2018 for the first-ever 16 over 1.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which coach has the most NCAA tournament wins?', choices: ['Mike Krzyzewski', 'John Wooden', 'Roy Williams', 'Dean Smith'], correctIndex: 0, category: 'NCAA', explanation: 'Coach K has 101 NCAA tournament wins with Duke.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'The odds of a perfect March Madness bracket are approximately:', choices: ['1 in 1 million', '1 in 1 billion', '1 in 9.2 quintillion', '1 in 120 billion'], correctIndex: 2, category: 'NCAA', explanation: 'The odds are approximately 1 in 9.2 quintillion.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'What seed has NEVER won the NCAA tournament?', choices: ['#8 seed', '#11 seed', '#16 seed', '#7 seed'], correctIndex: 2, category: 'NCAA', explanation: 'No #16 seed has ever won the NCAA tournament.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which conference has produced the most NCAA basketball champions?', choices: ['Big Ten', 'SEC', 'ACC', 'Pac-12'], correctIndex: 2, category: 'NCAA', explanation: 'The ACC has the most champions: Duke, UNC, NC State.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which round of March Madness is called the "Sweet 16"?', choices: ['First Round', 'Second Round', 'Regional Semifinals', 'Regional Finals'], correctIndex: 2, category: 'NCAA', explanation: 'The Sweet 16 is the regional semifinals with 16 teams left.', difficulty: TriviaDifficulty.hard),

    // MLB Hard
    TriviaQuestion(question: 'What is a "perfect game" in baseball?', choices: ['Hitting a home run every at-bat', 'No hits, walks, or errors for 9 innings', 'Winning by 10+ runs', 'Striking out every batter'], correctIndex: 1, category: 'MLB', explanation: 'A perfect game means no opposing batter reaches base.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which pitcher has the most career strikeouts?', choices: ['Roger Clemens', 'Randy Johnson', 'Nolan Ryan', 'Greg Maddux'], correctIndex: 2, category: 'MLB', explanation: 'Nolan Ryan holds the record with 5,714 career strikeouts.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Who hit the famous "Shot Heard Round the World" in 1951?', choices: ['Mickey Mantle', 'Bobby Thomson', 'Jackie Robinson', 'Ted Williams'], correctIndex: 1, category: 'MLB', explanation: 'Bobby Thomson hit the walk-off homer for the Giants against the Dodgers.', difficulty: TriviaDifficulty.hard),

    // General/NHL Hard
    TriviaQuestion(question: 'Who is known as "The Great One" in hockey?', choices: ['Mario Lemieux', 'Bobby Orr', 'Wayne Gretzky', 'Gordie Howe'], correctIndex: 2, category: 'NHL', explanation: 'Wayne Gretzky holds 61 NHL records.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'How long is an Olympic swimming pool?', choices: ['25 meters', '50 meters', '75 meters', '100 meters'], correctIndex: 1, category: 'General', explanation: 'An Olympic swimming pool is 50 meters long.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which Grand Slam tennis tournament is played on clay?', choices: ['Australian Open', 'Wimbledon', 'US Open', 'French Open'], correctIndex: 3, category: 'General', explanation: 'The French Open (Roland-Garros) is played on red clay.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'What is a "bust" in bracket terminology?', choices: ['A big upset that ruins brackets', 'A perfect bracket', 'A tie game', 'A first-round exit'], correctIndex: 0, category: 'General', explanation: 'A bust is a top seed that loses early, busting many brackets.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which country invented cricket?', choices: ['India', 'Australia', 'England', 'South Africa'], correctIndex: 2, category: 'General', explanation: 'Cricket originated in England in the 16th century.', difficulty: TriviaDifficulty.hard),
    TriviaQuestion(question: 'Which NHL team has won the most Stanley Cups?', choices: ['Toronto Maple Leafs', 'Detroit Red Wings', 'Montreal Canadiens', 'Boston Bruins'], correctIndex: 2, category: 'NHL', explanation: 'The Montreal Canadiens have won 24 Stanley Cups, the most in NHL history.', difficulty: TriviaDifficulty.hard),
  ];
}
