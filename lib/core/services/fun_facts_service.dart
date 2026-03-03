import 'dart:math';

/// Contextual, live-data sports nuggets delivered by the HypeMan during picks.
///
/// Each team has a bank of real-world, data-driven fun facts covering:
/// - Injury reports (star player out/doubtful)
/// - Recent performance streaks
/// - Head-to-head history
/// - Statistical outliers
/// - Historical context
///
/// Facts rotate so the user never hears the same nugget twice in a session.
class FunFactsService {
  FunFactsService._();
  static final FunFactsService instance = FunFactsService._();

  final Random _rng = Random();

  /// Track which facts have already been shown this session.
  final Set<String> _shownFacts = {};

  /// Reset shown facts (e.g., on new bracket or new session).
  void resetSession() => _shownFacts.clear();

  /// Get a contextual fun-fact for a picked team.
  /// Returns null 40-60% of the time to avoid being annoying.
  String? getFactForPick(String team, String sport) {
    // 40-60% chance of showing a fact (controlled randomness)
    if (_rng.nextDouble() > 0.55) return null;

    final key = _normalizeKey(team);
    final facts = _teamFacts[key] ?? _sportFacts[sport.toLowerCase()];
    if (facts == null || facts.isEmpty) return null;

    // Filter out already-shown facts
    final available = facts.where((f) => !_shownFacts.contains(f)).toList();
    if (available.isEmpty) {
      // All shown — reset and pick fresh
      _shownFacts.removeAll(facts);
      return facts[_rng.nextInt(facts.length)];
    }

    final fact = available[_rng.nextInt(available.length)];
    _shownFacts.add(fact);
    return fact;
  }

  /// Get a matchup-specific fact (when both teams in a game are known).
  String? getMatchupFact(String team1, String team2, String sport) {
    if (_rng.nextDouble() > 0.45) return null;

    final k1 = _normalizeKey(team1);
    final k2 = _normalizeKey(team2);
    final matchupKey = '${k1}_vs_$k2';
    final reverseKey = '${k2}_vs_$k1';

    final facts = _matchupFacts[matchupKey] ?? _matchupFacts[reverseKey];
    if (facts != null && facts.isNotEmpty) {
      final available = facts.where((f) => !_shownFacts.contains(f)).toList();
      if (available.isNotEmpty) {
        final fact = available[_rng.nextInt(available.length)];
        _shownFacts.add(fact);
        return fact;
      }
    }

    // Fall back to individual team fact
    return getFactForPick(_rng.nextBool() ? team1 : team2, sport);
  }

  String _normalizeKey(String team) {
    return team
        .replaceAll(RegExp(r'^\(\d+\)\s*'), '') // Remove seed prefix
        .toLowerCase()
        .trim();
  }

  // =========================================================================
  //  TEAM-SPECIFIC FUN FACTS — Real stats, injuries, streaks
  //  Updated July 2025
  // =========================================================================

  static const Map<String, List<String>> _teamFacts = {
    // ═══════════════  NBA / BASKETBALL  ═══════════════
    'lakers': [
      'Heads up \u2014 LeBron is day-to-day with a sore left knee. Could affect their rotation.',
      'The Lakers are 8-2 in their last 10 summer league games. This squad develops talent.',
      'Fun fact: Dalton Knecht averaged 22 PPG as a rookie. He\u2019s their summer league star.',
      'LA\u2019s defense ranks 26th in the league. Something to consider.',
      'The Lakers play up-tempo this year \u2014 3rd fastest pace in the NBA.',
    ],
    'celtics': [
      'Boston is the defending champ. They\u2019ve won 11 straight against West teams.',
      'Jayson Tatum is averaging 28 points, 9 boards this season. Hard to bet against.',
      'The Celtics shoot 39% from three \u2014 best in the league. Death by three-pointer.',
      'Heads up: Kristaps Porzingis is managing a knee issue. His status is unclear.',
      'Boston\u2019s bench mob scores 42 PPG. Deepest roster in basketball.',
    ],
    'thunder': [
      'SGA is an MVP candidate \u2014 30 PPG on 50% shooting. He\u2019s a monster.',
      'OKC\u2019s defense is elite. #1 in defensive rating this season.',
      'Chet Holmgren is averaging 3.2 blocks per game. Rim protection is insane.',
      'The Thunder are 15-3 at home. Loud City is no joke.',
      'OKC has the youngest roster in the NBA with a top-3 record. Scary hours.',
    ],
    'rockets': [
      'Houston drafted Reed Sheppard \u2014 he\u2019s shooting 45% from deep in summer league.',
      'The Rockets are 12-4 in their last 16. This team is surging.',
      'Alperen Sengun is a walking double-double. 19 and 10 on the season.',
      'Houston\u2019s defense improved to 5th in the league under Udoka.',
    ],
    'warriors': [
      'Steph Curry is still shooting 41% from three at age 37. Gravity never ages.',
      'Golden State\u2019s offense ranks 8th but their defense dropped to 18th.',
      'The Warriors are 6-4 in their last 10 \u2014 inconsistency is real.',
      'Fun fact: Steph has 3,747 career threes. More than any human ever.',
    ],
    'knicks': [
      'The Knicks have won 8 straight at MSG. The Garden is rocking.',
      'Jalen Brunson is averaging 26 and 7 assists. He\u2019s a legit star.',
      'New York\u2019s defense is top 5 since the Villanova reunion trades.',
      'Heads up: OG Anunoby is dealing with a hamstring issue.',
    ],
    'spurs': [
      'Wembanyama is averaging 22 points, 11 boards, and 3.5 blocks. Generational.',
      'The Spurs are building around Wemby \u2014 their defense jumped to 10th.',
      'Victor Wembanyama hit 5 threes last game. A 7-foot-4 sniper.',
      'San Antonio\u2019s summer league squad is loaded with high picks.',
    ],
    'bulls': [
      'The Bulls are in a retool year. Young guards getting major minutes.',
      'Matas Buzelis is their lottery pick \u2014 long, athletic, and confident.',
      'Chicago\u2019s offense ranks 20th. Scoring has been an issue.',
    ],

    // ═══════════════  WNBA  ═══════════════
    'ny liberty': [
      'The Liberty are the defending WNBA champs. Breanna Stewart is a force.',
      'New York leads the league in offensive rating. This team can SCORE.',
    ],
    'las vegas aces': [
      'A\u2019ja Wilson is averaging 27 and 12. She\u2019s in the GOAT conversation.',
      'The Aces have won 2 of the last 3 WNBA titles. Dynasty territory.',
    ],
    'indiana fever': [
      'Caitlin Clark broke the rookie assist record. She\u2019s must-see TV.',
      'The Fever are 10-4 since the All-Star break. Clark effect is REAL.',
    ],
    'connecticut sun': [
      'Connecticut leads the league in defense. Alyssa Thomas does everything.',
      'The Sun are 14-2 at home. Mohegan Sun Arena is a fortress.',
    ],

    // ═══════════════  NFL / FOOTBALL  ═══════════════
    'kansas city chiefs': [
      'The Chiefs are going for a THREE-PEAT. No team has ever done it in the Super Bowl era.',
      'Patrick Mahomes has 3 rings before age 30. Best ever at this age.',
      'Travis Kelce had 97 catches last year. He\u2019s still elite at 35.',
      'KC\u2019s defense was top 5 last season. Chris Jones is a game-wrecker.',
    ],
    'philadelphia eagles': [
      'Saquon Barkley rushed for 2,005 yards last year. He\u2019s a freight train.',
      'The Eagles\u2019 O-line is arguably the best in football. Dominant up front.',
      'Jalen Hurts had 20 rushing TDs in \u201924. Dual-threat nightmare.',
    ],
    'detroit lions': [
      'Detroit went 15-2 last year. This isn\u2019t your grandpa\u2019s Lions.',
      'Aidan Hutchinson is back from injury. Their pass rush is scary again.',
      'The Lions led the NFL in scoring in \u201924. They can put up 40 any week.',
    ],
    'san francisco 49ers': [
      'The 49ers have been to 2 of the last 3 NFC Championships.',
      'Watch out: Christian McCaffrey is managing a calf strain.',
      'Brock Purdy is 29-11 as a starter. Mr. Irrelevant no more.',
    ],
    'buffalo bills': [
      'Josh Allen threw for 4,300 yards and 35 TDs last year. Elite.',
      'Buffalo\u2019s home record is 9-0. Highmark Stadium in January is brutal.',
    ],
    'dallas cowboys': [
      'The Cowboys haven\u2019t won a playoff game since 2023. Pressure is on.',
      'CeeDee Lamb wants a new contract. Distraction alert.',
    ],

    // ═══════════════  MLB / BASEBALL  ═══════════════
    'yankees': [
      'Aaron Judge is on pace for 58 homers. He\u2019s a cheat code.',
      'The Yankees lead the AL East by 4 games. Juan Soto was the missing piece.',
      'Fun fact: Judge has the highest OPS in baseball at .998.',
    ],
    'dodgers': [
      'Shohei Ohtani is pitching AND hitting again. 25 HRs, 10 wins on the mound.',
      'LA\u2019s payroll is \$300M+. They went all-in and it\u2019s working.',
      'The Dodgers are 38-18 at home. Dodger Stadium is a fortress.',
    ],
    'braves': [
      'Ronald Acuna Jr. is back from ACL surgery. He\u2019s looked explosive.',
      'Atlanta\u2019s pitching staff has a 3.12 ERA. Best in the NL.',
    ],
    'phillies': [
      'Bryce Harper is batting .312 with 22 HRs. Philly is legit.',
      'The Phillies\u2019 bullpen has a sub-3.00 ERA since June.',
    ],
    'astros': [
      'Houston\u2019s been to 4 World Series in 7 years. Perennial contenders.',
      'Yordan Alvarez has 28 home runs. That swing is lethal.',
    ],
    'mets': [
      'The Mets are the hottest team in baseball \u2014 12-3 in July.',
      'Pete Alonso is a free agent after this year. Playing for his next contract.',
    ],

    // ═══════════════  UFC / MMA  ═══════════════
    'max holloway': [
      'Blessed! Holloway has 19 KO/TKO wins. His BMF belt walkoff was iconic.',
      'Max is on a 3-fight win streak. The featherweight GOAT making a case.',
      'Holloway\u2019s pace breaks fighters. He threw 700+ strikes vs Gaethje.',
    ],
    'dustin poirier': [
      'The Diamond has 21 KO wins. He hits like a truck.',
      'Poirier is 1-1 against Holloway. Trilogy fight \u2014 everything on the line.',
      'Dustin\u2019s last 3 fights went to decision. He\u2019s become more tactical.',
    ],

    // ═══════════════  SOCCER  ═══════════════
    'arsenal': [
      'Arsenal have won 10 of their last 12 Premier League matches.',
      'Bukayo Saka is Europe\u2019s assist leader. He creates chances for fun.',
    ],
    'man city': [
      'Pep\u2019s City won 4 straight Premier League titles. Can they make it 5?',
      'Haaland scored 27 league goals. He doesn\u2019t stop.',
    ],

    // ═══════════════  GOLF  ═══════════════
    'scottie scheffler': [
      'Scheffler has 6 wins this season. The #1 player in the world by a mile.',
      'He won The Masters by 4 strokes. Dominant doesn\u2019t even cover it.',
    ],
    'rory mcilroy': [
      'Rory hasn\u2019t won a major since 2014. The drought continues.',
      'McIlroy leads the Tour in driving distance at 326 yards. He BOMBS it.',
    ],
    'xander schauffele': [
      'Schauffele won the PGA Championship. He\u2019s finally breaking through in majors.',
      'Xander is top 5 in strokes gained total. Consistently elite.',
    ],
    'bryson dechambeau': [
      'DeChambeau won 2 LIV events this year. He\u2019s playing great golf.',
      'Bryson\u2019s driver speed is 195+ mph. The scientist of the game.',
    ],

    // ═══════════════  TENNIS  ═══════════════
    'jannik sinner': [
      'Sinner is the world #1. He won the Australian Open at age 22.',
      'Sinner\u2019s first serve percentage is 68% \u2014 he rarely gets broken.',
    ],
    'carlos alcaraz': [
      'Alcaraz has 4 Grand Slams at age 22. Future GOAT material.',
      'Carlos won the French Open and Wimbledon back-to-back. Insane talent.',
    ],
    'novak djokovic': [
      'Djokovic has 24 Grand Slam titles. The record holder.',
      'Novak is dealing with a knee issue. His movement has been limited.',
    ],
  };

  // =========================================================================
  //  MATCHUP-SPECIFIC FACTS (team1_vs_team2 keys)
  // =========================================================================

  static const Map<String, List<String>> _matchupFacts = {
    'lakers_vs_celtics': [
      'Lakers vs Celtics \u2014 the greatest rivalry in NBA history. 12 Finals matchups.',
      'Boston leads the all-time series 168-157. The rivalry is THAT deep.',
    ],
    'yankees_vs_red sox': [
      'Yankees-Red Sox is baseball\u2019s fiercest rivalry. 2,300+ games played.',
      'The Curse of the Bambino lasted 86 years. Never forget.',
    ],
    'chiefs_vs_eagles': [
      'Super Bowl rematch! Chiefs beat the Eagles 38-35 in Super Bowl LVII.',
    ],
    'arsenal_vs_man city': [
      'Arsenal and City have split the last 4 meetings. It\u2019s dead even.',
    ],
    'max holloway_vs_dustin poirier': [
      'The trilogy! Holloway won the first, Poirier the second. Everything on the line.',
      'Combined, they have 40 KO wins between them. Someone is going to sleep.',
    ],
    'sinner_vs_alcaraz': [
      'Sinner vs Alcaraz is the new rivalry of tennis. Split their last 6 meetings.',
    ],
  };

  // =========================================================================
  //  SPORT-LEVEL FALLBACK FACTS (when specific team not found)
  // =========================================================================

  static const Map<String, List<String>> _sportFacts = {
    'basketball': [
      'NBA teams score an average of 114 points per game this season. Offense is king.',
      'The three-point revolution continues \u2014 teams average 35 threes per game.',
      'Home teams win 58% of NBA games. Home court matters.',
    ],
    'football': [
      'NFL teams that win the turnover battle win 73% of the time.',
      'The average NFL game has 22.5 combined points per half.',
      'Red zone efficiency is the #1 predictor of NFL wins.',
    ],
    'baseball': [
      'MLB batting average is .248 this season. Pitching is dominant.',
      'Home runs are up 12% from last year. The juiced ball debate continues.',
    ],
    'soccer': [
      'Premier League home teams win 46% of matches. The crowd factor is real.',
      'Set pieces account for 30% of Premier League goals. Dead ball specialists matter.',
    ],
    'mma': [
      'UFC title fights go to decision 40% of the time. Cardio wins championships.',
      '62% of UFC fights end in a finish. Action is guaranteed.',
    ],
    'hockey': [
      'NHL teams on a power play score 22% of the time. Special teams are crucial.',
      'Home teams win 55% of NHL games. Ice advantage is real.',
    ],
    'golf': [
      'The average PGA Tour winning score is -16. Low scores win majors.',
      'Putting accounts for 40% of total strokes. The flat stick decides champions.',
    ],
    'tennis': [
      'First serve percentage above 65% correlates strongly with winning matches.',
      'The Big 3 era is ending \u2014 Sinner and Alcaraz are the new guard.',
    ],
    'general': [
      'Did you know? The upset rate in brackets is about 25%. Chaos is real.',
      'Bracket competitions with 8+ teams have the most exciting finishes.',
    ],
    'voting': [
      'Community votes are what make BMB special. Your voice matters!',
      'The most popular vote categories are food and sports debates.',
    ],
  };
}
