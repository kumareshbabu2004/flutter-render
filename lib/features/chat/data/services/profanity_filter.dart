/// Comprehensive content moderation system for BMB chat rooms.
///
/// Blocks and flags messages containing:
/// - Vulgar language & profanity (including obfuscation tricks)
/// - Racial, ethnic, gender, religious, and sexual-orientation slurs
/// - Harassment, threats, and bullying
/// - Political discussion and debate
/// - Discriminatory language of any kind
///
/// Severity levels:
///   blocked  = message is NEVER sent (hard profanity/slurs/threats/discrimination)
///   flagged  = message is sent but flagged for moderator review
///   clean    = message passes all checks
class ProfanityFilter {
  ProfanityFilter._();

  // ─── RESULT CONSTANTS ─────────────────────────────────────────────────
  static const String clean = 'clean';
  static const String flagged = 'flagged';
  static const String blocked = 'blocked';

  // ─── 1. VULGAR / PROFANE WORDS ────────────────────────────────────────
  static const List<String> _profanityExact = [
    // Hard profanity
    'fuck', 'fucker', 'fucking', 'fucked', 'motherfucker', 'motherfucking',
    'shit', 'shitty', 'bullshit', 'horseshit', 'dipshit', 'shithead',
    'ass', 'asshole', 'dumbass', 'jackass', 'smartass', 'fatass', 'badass',
    'bitch', 'bitches', 'bitchy', 'sonofabitch',
    'dick', 'dickhead', 'dickweed',
    'cock', 'cocksucker',
    'pussy', 'cunt', 'twat',
    'bastard', 'whore', 'slut', 'skank', 'hoe',
    'piss', 'pissed', 'pissing',
    'damn', 'goddamn', 'damnit',
    'crap', 'crappy',
    'douche', 'douchebag',
    'wank', 'wanker',
    'bollocks', 'arse', 'arsehole',
    'tits', 'boob', 'boobs',
    'stfu', 'gtfo', 'lmfao',
  ];

  // ─── 2. RACIAL / ETHNIC SLURS ────────────────────────────────────────
  static const List<String> _racialSlurs = [
    'nigger', 'nigga', 'negro', 'negroid',
    'spic', 'spick', 'wetback', 'beaner', 'greaser',
    'chink', 'gook', 'zipperhead', 'slant',
    'kike', 'heeb', 'hymie',
    'cracker', 'honky', 'redneck', 'whitetrash',
    'towelhead', 'raghead', 'sandnigger', 'camel jockey',
    'coon', 'darkie', 'jigaboo', 'porchmonkey',
    'redskin', 'injun', 'squaw',
    'polack', 'dago', 'wop', 'guido',
    'paki', 'chinaman',
  ];

  // ─── 3. GENDER / SEXUALITY / IDENTITY SLURS ──────────────────────────
  static const List<String> _genderSlurs = [
    'faggot', 'fag', 'faggy',
    'dyke', 'lesbo', 'lezzie',
    'homo', 'queer',
    'tranny', 'shemale', 'heshe', 'ladyboy', 'trap',
    'retard', 'retarded', 'tard',
    'spaz', 'spastic',
    'cripple',
  ];

  // ─── 4. RELIGIOUS SLURS & HATE ───────────────────────────────────────
  static const List<String> _religiousSlurs = [
    'christard', 'jesusfreak',
    'muzzie', 'goatfucker',
    'zionist pig', 'kike',
    'bible thumper', 'bible basher',
    'infidel', 'heathen',
    'cultist',
  ];

  // ─── 5. HARASSMENT & THREATS ─────────────────────────────────────────
  static const List<String> _harassmentPhrases = [
    'kill yourself', 'kys',
    'go die', 'hope you die', 'i hope you die',
    'hang yourself', 'neck yourself', 'end yourself',
    'go kill yourself',
    'i will find you', 'i know where you live',
    'i will hurt you', 'i will beat you up',
    'you should die', 'you deserve to die',
    'no one likes you', 'everyone hates you',
    'nobody wants you', 'nobody cares about you',
    'go away and die',
    'you are trash', 'you are garbage',
    'ur trash', 'ur garbage',
    'you suck', 'you are worthless',
    'shut the fuck up', 'shut up idiot',
    'i will kill', 'gonna kill',
    'rape', 'molest',
    'i will rape', 'get raped',
    'shoot you', 'stab you', 'beat your ass',
  ];

  // ─── 6. POLITICAL KEYWORDS & PHRASES ─────────────────────────────────
  // Block political discussion entirely per BMB policy
  static const List<String> _politicalTerms = [
    // Political figures & parties
    'trump', 'biden', 'obama', 'maga', 'democrat', 'republican',
    'liberal', 'conservative', 'libertarian', 'socialist', 'communist',
    'marxist', 'fascist', 'antifa', 'proud boys',
    'gop', 'dnc', 'rnc',
    'left wing', 'right wing', 'leftwing', 'rightwing',
    'libtard', 'trumptard', 'snowflake',
    'woke', 'anti-woke', 'cancel culture',
    'defund the police', 'blue lives matter', 'all lives matter',
    'build the wall', 'open borders',
    'gun control', 'gun rights', 'second amendment', '2nd amendment',
    'pro-life', 'pro-choice', 'abortion',
    // Political discussion triggers
    'vote for', 'voting for', 'elected', 'election',
    'congress', 'senate', 'house of representatives',
    'political', 'politician', 'politics',
    'immigration policy', 'border policy',
    'supreme court', 'scotus',
  ];

  // ─── 7. DISCRIMINATION PHRASES ───────────────────────────────────────
  static const List<String> _discriminationPhrases = [
    'go back to your country', 'go back to where you came from',
    'speak english', 'learn english',
    'you people', 'your kind', 'those people',
    'white power', 'white supremacy', 'white pride',
    'black power', 'black supremacy',
    'master race', 'superior race', 'inferior race',
    'hate all', 'hate every',
    'all cops are', 'acab',
    'illegal alien', 'illegals',
    'anchor baby',
    'gay agenda', 'transgender agenda',
    'conversion therapy',
    'god hates',
    'burn in hell',
  ];

  // ─── 8. OBFUSCATION PATTERNS (regex) ─────────────────────────────────
  static const List<String> _obfuscationPatterns = [
    r'f+[\s.*]*[u\*@]+[\s.*]*[c\*@]+[\s.*]*[k\*@]+',
    r's+[\s.*]*h+[\s.*]*[i1!]+[\s.*]*[t\*@]+',
    r'b+[\s.*]*[i1!]+[\s.*]*[t\*@]+[\s.*]*[c\*@]+[\s.*]*h+',
    r'a+[\s.*]*[s\$]+[\s.*]*[s\$]+[\s.*]*h+[\s.*]*[o0]+[\s.*]*l+[\s.*]*e+',
    r'n+[\s.*]*[i1!]+[\s.*]*[g9]+[\s.*]*[g9]+[\s.*]*[e3]+[\s.*]*r+',
    r'f+[\s.*]*[a@]+[\s.*]*[g9]+[\s.*]*[g9]+[\s.*]*[o0]+[\s.*]*[t\*]+',
    r'r+[\s.*]*[e3]+[\s.*]*[t\*]+[\s.*]*[a@]+[\s.*]*r+[\s.*]*d+',
    r'd+[\s.*]*[i1!]+[\s.*]*[c\*@]+[\s.*]*[k\*@]+',
    r'c+[\s.*]*[u\*@]+[\s.*]*[n\*]+[\s.*]*[t\*]+',
    r'w+[\s.*]*h+[\s.*]*[o0]+[\s.*]*r+[\s.*]*[e3]+',
    r't+[\s.*]*r+[\s.*]*[a@]+[\s.*]*n+[\s.*]*n+[\s.*]*y+',
  ];

  // ═══════════════════════════════════════════════════════════════════════
  //  MAIN CHECK METHOD
  // ═══════════════════════════════════════════════════════════════════════
  static FilterResult check(String message) {
    final lower = message.toLowerCase().trim();
    final stripped = _stripSpecialChars(lower);
    final words = stripped.split(RegExp(r'\s+'));

    // ── PASS 1: Harassment & threats (highest severity) ──────────────
    for (final phrase in _harassmentPhrases) {
      if (lower.contains(phrase)) {
        return FilterResult(
          status: blocked,
          reason: 'Message contains harassment or threatening language.',
          category: FilterCategory.harassment,
          originalMessage: message,
        );
      }
    }

    // ── PASS 2: Racial / ethnic slurs ───────────────────────────────
    for (final word in words) {
      for (final slur in _racialSlurs) {
        if (word == slur || (slur.contains(' ') && lower.contains(slur))) {
          return FilterResult(
            status: blocked,
            reason: 'Message contains racial or ethnic slurs. This is strictly prohibited.',
            category: FilterCategory.racialDiscrimination,
            originalMessage: message,
          );
        }
      }
    }

    // ── PASS 3: Gender / sexuality / identity slurs ─────────────────
    for (final word in words) {
      for (final slur in _genderSlurs) {
        if (word == slur) {
          return FilterResult(
            status: blocked,
            reason: 'Message contains discriminatory language targeting gender or identity. This is strictly prohibited.',
            category: FilterCategory.genderDiscrimination,
            originalMessage: message,
          );
        }
      }
    }

    // ── PASS 4: Religious slurs & hate ──────────────────────────────
    for (final slur in _religiousSlurs) {
      if (slur.contains(' ') ? lower.contains(slur) : words.contains(slur)) {
        return FilterResult(
          status: blocked,
          reason: 'Message contains religious discrimination. This is strictly prohibited.',
          category: FilterCategory.religiousDiscrimination,
          originalMessage: message,
        );
      }
    }

    // ── PASS 5: Discrimination phrases ──────────────────────────────
    for (final phrase in _discriminationPhrases) {
      if (lower.contains(phrase)) {
        return FilterResult(
          status: blocked,
          reason: 'Message contains discriminatory content. This violates our community guidelines.',
          category: FilterCategory.discrimination,
          originalMessage: message,
        );
      }
    }

    // ── PASS 6: Political content ───────────────────────────────────
    for (final term in _politicalTerms) {
      if (term.contains(' ') ? lower.contains(term) : words.contains(term)) {
        return FilterResult(
          status: blocked,
          reason: 'Political discussion is not allowed in BMB chat rooms. Keep it about sports and brackets!',
          category: FilterCategory.political,
          originalMessage: message,
        );
      }
    }

    // ── PASS 7: Profanity (exact match) ─────────────────────────────
    for (final word in words) {
      for (final profanity in _profanityExact) {
        if (word == profanity) {
          return FilterResult(
            status: blocked,
            reason: 'Message contains vulgar or inappropriate language.',
            category: FilterCategory.profanity,
            originalMessage: message,
          );
        }
      }
    }

    // ── PASS 8: Obfuscation patterns (f**k, sh!t, a$$, etc.) ───────
    for (final pattern in _obfuscationPatterns) {
      if (RegExp(pattern, caseSensitive: false).hasMatch(stripped)) {
        return FilterResult(
          status: blocked,
          reason: 'Message contains disguised inappropriate language.',
          category: FilterCategory.profanity,
          originalMessage: message,
        );
      }
    }

    // ── PASS 9: Excessive caps (potential aggression) ───────────────
    if (message.length > 10) {
      final upperCount = message.runes.where((r) {
        final c = String.fromCharCode(r);
        return c == c.toUpperCase() && c != c.toLowerCase();
      }).length;
      final ratio = upperCount / message.length;
      if (ratio > 0.7) {
        return FilterResult(
          status: flagged,
          reason: 'Excessive caps detected (potential aggressive tone).',
          category: FilterCategory.spam,
          originalMessage: message,
        );
      }
    }

    // ── PASS 10: Spam-like repeated characters ──────────────────────
    if (RegExp(r'(.)\1{5,}').hasMatch(message)) {
      return FilterResult(
        status: flagged,
        reason: 'Spam-like repeated characters detected.',
        category: FilterCategory.spam,
        originalMessage: message,
      );
    }

    return FilterResult(
      status: clean,
      reason: null,
      category: null,
      originalMessage: message,
    );
  }

  /// Strips common substitution characters so "f*ck" becomes "fck", etc.
  static String _stripSpecialChars(String input) {
    return input
        .replaceAll(RegExp(r'[*@#\$!10_.\-]'), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ');
  }

  /// Returns a censored version of the message (blocked words replaced with
  /// asterisks) for display if you prefer censored text over full blocking.
  static String censor(String message) {
    var result = message;
    final lower = message.toLowerCase();
    final allBlocked = [
      ..._profanityExact,
      ..._racialSlurs,
      ..._genderSlurs,
    ];
    for (final word in allBlocked) {
      final idx = lower.indexOf(word);
      if (idx != -1) {
        final replacement = '*' * word.length;
        result = result.replaceRange(idx, idx + word.length, replacement);
      }
    }
    return result;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  FILTER CATEGORY
// ═══════════════════════════════════════════════════════════════════════════
enum FilterCategory {
  profanity,
  racialDiscrimination,
  genderDiscrimination,
  religiousDiscrimination,
  discrimination,
  harassment,
  political,
  spam,
}

// ═══════════════════════════════════════════════════════════════════════════
//  FILTER RESULT
// ═══════════════════════════════════════════════════════════════════════════
class FilterResult {
  final String status; // 'clean', 'flagged', or 'blocked'
  final String? reason;
  final FilterCategory? category;
  final String originalMessage;

  const FilterResult({
    required this.status,
    this.reason,
    this.category,
    required this.originalMessage,
  });

  bool get isClean => status == ProfanityFilter.clean;
  bool get isFlagged => status == ProfanityFilter.flagged;
  bool get isBlocked => status == ProfanityFilter.blocked;

  /// User-facing icon for the block reason category
  String get categoryLabel {
    switch (category) {
      case FilterCategory.profanity:
        return 'Vulgar Language';
      case FilterCategory.racialDiscrimination:
        return 'Racial Discrimination';
      case FilterCategory.genderDiscrimination:
        return 'Gender/Identity Discrimination';
      case FilterCategory.religiousDiscrimination:
        return 'Religious Discrimination';
      case FilterCategory.discrimination:
        return 'Discriminatory Content';
      case FilterCategory.harassment:
        return 'Harassment/Threats';
      case FilterCategory.political:
        return 'Political Content';
      case FilterCategory.spam:
        return 'Spam/Excessive Caps';
      case null:
        return 'Unknown';
    }
  }
}
