/// Post-processes speech-to-text output for sports betting / Pick 'Em
/// contexts so that spoken spread notation is turned into the standard
/// written form.
///
/// Examples:
///   "Chicago Bears minus 3 point 5"   → "Chicago Bears -3.5"
///   "Green Bay Packers plus 1 point 5" → "Green Bay Packers +1.5"
///   "Dallas Cowboys minus seven"       → "Dallas Cowboys -7"
///   "Bills plus 3"                     → "Bills +3"
///   "Patriots minus 2 point 5"         → "Patriots -2.5"
///   "Rams even"                        → "Rams EVEN"
///   "Chiefs pick"                      → "Chiefs PK"
///   "Texans pick em"                   → "Texans PK"
///   "over 45 point 5"                  → "Over 45.5"
///   "under 200 point 5"               → "Under 200.5"
class SportsSpeechProcessor {
  SportsSpeechProcessor._();

  // Spoken word → digit mapping for common spread values
  static const Map<String, String> _wordToNumber = {
    'zero': '0',
    'one': '1',
    'two': '2',
    'three': '3',
    'four': '4',
    'five': '5',
    'six': '6',
    'seven': '7',
    'eight': '8',
    'nine': '9',
    'ten': '10',
    'eleven': '11',
    'twelve': '12',
    'thirteen': '13',
    'fourteen': '14',
    'fifteen': '15',
    'sixteen': '16',
    'seventeen': '17',
    'eighteen': '18',
    'nineteen': '19',
    'twenty': '20',
    'twenty one': '21',
    'twenty-one': '21',
    'twenty two': '22',
    'twenty-two': '22',
    'twenty three': '23',
    'twenty-three': '23',
    'twenty four': '24',
    'twenty-four': '24',
    'twenty five': '25',
    'twenty-five': '25',
    'thirty': '30',
    'thirty five': '35',
    'thirty-five': '35',
    'forty': '40',
    'forty five': '45',
    'forty-five': '45',
    'fifty': '50',
    'a hundred': '100',
    'one hundred': '100',
    'hundred': '100',
  };

  /// Process raw speech-to-text output into clean sports notation.
  ///
  /// This is designed to be called on every interim AND final result from
  /// the speech engine so the user sees real-time formatting in the field.
  static String process(String raw) {
    if (raw.trim().isEmpty) return raw;

    var text = raw.trim();

    // ── 1. Normalise "pick em" / "pick 'em" → PK ──
    text = text.replaceAll(RegExp(r"\bpick\s*(?:'?em|him)\b", caseSensitive: false), 'PK');
    text = text.replaceAll(RegExp(r'\bpick\b$', caseSensitive: false), 'PK');

    // ── 2. Normalise "even" → EVEN ──
    text = text.replaceAll(RegExp(r'\beven\b$', caseSensitive: false), 'EVEN');
    text = text.replaceAll(RegExp(r'\beven\s*money\b', caseSensitive: false), 'EVEN');

    // ── 3. Convert "over" / "under" at the start ──
    text = text.replaceAllMapped(
      RegExp(r'^\b(over|under)\b', caseSensitive: false),
      (m) => m[1]!.substring(0, 1).toUpperCase() + m[1]!.substring(1).toLowerCase(),
    );

    // ── 4. Handle "minus" / "negative" → "-" ──
    text = text.replaceAllMapped(
      RegExp(r'\b(minus|negative)\s+', caseSensitive: false),
      (m) => '-',
    );

    // ── 5. Handle "plus" / "positive" → "+" ──
    text = text.replaceAllMapped(
      RegExp(r'\b(plus|positive)\s+', caseSensitive: false),
      (m) => '+',
    );

    // ── 6. Convert spoken number-words to digits FIRST ──
    // This must happen before "point" / "and a half" so that
    // "six and a half" → "6 and a half" → "6.5" works correctly.
    // Process longer phrases first ("twenty one" before "twenty")
    final sortedWords = _wordToNumber.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in sortedWords) {
      final pattern = RegExp('\\b${RegExp.escape(word)}\\b', caseSensitive: false);
      text = text.replaceAllMapped(pattern, (m) => _wordToNumber[word]!);
    }

    // ── 7. Handle "point" / "and a half" between numbers ──
    // "3 point 5" → "3.5"
    text = text.replaceAllMapped(
      RegExp(r'(\d)\s*point\s+(\d)', caseSensitive: false),
      (m) => '${m[1]}.${m[2]}',
    );
    // "3 and a half" → "3.5"  (covers "six and a half" → "6 and a half" → "6.5")
    text = text.replaceAllMapped(
      RegExp(r'(\d)\s+and\s+a\s+half\b', caseSensitive: false),
      (m) => '${m[1]}.5',
    );
    // Standalone "and a half" at end
    text = text.replaceAllMapped(
      RegExp(r'\band\s+a\s+half\b', caseSensitive: false),
      (m) => '.5',
    );

    // ── 8. Handle "half" standalone after +/- or number → ".5" ──
    text = text.replaceAllMapped(
      RegExp(r'(\d)\s+half\b', caseSensitive: false),
      (m) => '${m[1]}.5',
    );

    // ── 9. Clean up extra spaces ──
    text = text.replaceAll(RegExp(r'\s{2,}'), ' ').trim();

    // ── 10. Remove trailing "point" if incomplete ──
    text = text.replaceAll(RegExp(r'\s*point\s*$', caseSensitive: false), '');

    // ── 11. Auto-correct common team names using fuzzy matching ──
    text = _autoCorrectTeamName(text);

    return text;
  }

  // ─── TEAM NAME AUTO-RECOGNITION ────────────────────────────
  // A static map of commonly spoken short-forms / mis-hearings
  // to official team names. These are applied AFTER number processing
  // so spread suffixes are preserved.
  static const Map<String, String> _teamAliases = {
    // NFL
    'niners': 'San Francisco 49ers',
    '49ers': 'San Francisco 49ers',
    'forty niners': 'San Francisco 49ers',
    'the niners': 'San Francisco 49ers',
    'pack': 'Green Bay Packers',
    'the pack': 'Green Bay Packers',
    'pats': 'New England Patriots',
    'the pats': 'New England Patriots',
    'cards': 'Arizona Cardinals',
    'the cards': 'Arizona Cardinals',
    'jags': 'Jacksonville Jaguars',
    'the jags': 'Jacksonville Jaguars',
    'bolts': 'Los Angeles Chargers',
    'the bolts': 'Los Angeles Chargers',
    'boys': 'Dallas Cowboys',
    'the boys': 'Dallas Cowboys',
    'fins': 'Miami Dolphins',
    'the fins': 'Miami Dolphins',
    'skins': 'Washington Commanders',
    'commies': 'Washington Commanders',
    'nats': 'Washington Nationals',
    'philly': 'Philadelphia Eagles',
    // NBA
    'sixers': 'Philadelphia 76ers',
    'the sixers': 'Philadelphia 76ers',
    'dubs': 'Golden State Warriors',
    'the dubs': 'Golden State Warriors',
    'blazers': 'Portland Trail Blazers',
    'the blazers': 'Portland Trail Blazers',
    'wolves': 'Minnesota Timberwolves',
    't-wolves': 'Minnesota Timberwolves',
    // NHL
    'habs': 'Montreal Canadiens',
    'the habs': 'Montreal Canadiens',
    'leafs': 'Toronto Maple Leafs',
    'the leafs': 'Toronto Maple Leafs',
    'caps': 'Washington Capitals',
    'the caps': 'Washington Capitals',
    'pens': 'Pittsburgh Penguins',
    'the pens': 'Pittsburgh Penguins',
    'avs': 'Colorado Avalanche',
    'the avs': 'Colorado Avalanche',
    'wings': 'Detroit Red Wings',
    'red wings': 'Detroit Red Wings',
    'bolts hockey': 'Tampa Bay Lightning',
    // MLB
    'sox': 'Boston Red Sox',
    'red sox': 'Boston Red Sox',
    'white sox': 'Chicago White Sox',
    'cubbies': 'Chicago Cubs',
    'the cubbies': 'Chicago Cubs',
    'yanks': 'New York Yankees',
    'the yanks': 'New York Yankees',
    'dodgers': 'Los Angeles Dodgers',
    'the dodgers': 'Los Angeles Dodgers',
  };

  /// Remembers user-typed team names for the current session so that
  /// subsequent speech can be auto-corrected to match.
  static final Set<String> _sessionTeamMemory = {};

  /// Call this whenever the user manually types or confirms a team name
  /// so the processor can learn it for fuzzy matching.
  static void rememberTeam(String name) {
    if (name.trim().length >= 3) _sessionTeamMemory.add(name.trim());
  }

  /// Clear the session memory (call on app restart or new bracket).
  static void clearMemory() => _sessionTeamMemory.clear();

  /// Auto-correct the team name portion of the text.
  /// Preserves any trailing spread (e.g. "-3.5", "+7").
  static String _autoCorrectTeamName(String text) {
    // Extract trailing spread/number from the text
    final spreadMatch = RegExp(r'\s*([+-]\d+\.?\d*|\bPK\b|\bEVEN\b)\s*$').firstMatch(text);
    final String teamPart;
    final String spreadPart;
    if (spreadMatch != null) {
      teamPart = text.substring(0, spreadMatch.start).trim();
      spreadPart = ' ${spreadMatch.group(0)!.trim()}';
    } else {
      teamPart = text;
      spreadPart = '';
    }

    // Check static aliases first (exact match, case-insensitive)
    final lower = teamPart.toLowerCase();
    for (final entry in _teamAliases.entries) {
      if (lower == entry.key) {
        return '${entry.value}$spreadPart';
      }
    }

    // Check session memory for fuzzy matches (Levenshtein-like prefix match)
    // If the spoken text closely matches a previously entered team, auto-correct.
    if (_sessionTeamMemory.isNotEmpty && teamPart.length >= 4) {
      for (final known in _sessionTeamMemory) {
        if (known.toLowerCase().startsWith(teamPart.toLowerCase())) {
          return '$known$spreadPart';
        }
        if (teamPart.toLowerCase().startsWith(known.toLowerCase().split(' ').first)) {
          // Partial city match — compare more closely
          final similarity = _similarity(teamPart.toLowerCase(), known.toLowerCase());
          if (similarity > 0.75) {
            return '$known$spreadPart';
          }
        }
      }
    }

    return text;
  }

  /// Simple similarity metric (Dice coefficient on bigrams).
  static double _similarity(String a, String b) {
    if (a == b) return 1.0;
    if (a.length < 2 || b.length < 2) return 0.0;
    final bigramsA = <String>{};
    for (int i = 0; i < a.length - 1; i++) {
      bigramsA.add(a.substring(i, i + 2));
    }
    int matches = 0;
    for (int i = 0; i < b.length - 1; i++) {
      if (bigramsA.contains(b.substring(i, i + 2))) matches++;
    }
    return (2.0 * matches) / (a.length - 1 + b.length - 1);
  }
}
