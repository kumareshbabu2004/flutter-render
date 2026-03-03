/// Centralized team logo URL mapping for professional sports teams.
/// Uses ESPN CDN for reliable, high-quality team logos.
/// Format: https://a.espncdn.com/i/teamlogos/{league}/500/{team_id}.png
///
/// CRITICAL: League-aware lookups prevent cross-league contamination.
/// e.g. "Arizona" in a Basketball bracket → Arizona Wildcats (NCAA), not
/// the Arizona Cardinals (NFL).
class TeamLogos {
  TeamLogos._();

  // ─── ESPN CDN Logo URLs ──────────────────────────────────────
  static const String _espnNfl = 'https://a.espncdn.com/i/teamlogos/nfl/500';
  static const String _espnNba = 'https://a.espncdn.com/i/teamlogos/nba/500';
  static const String _espnMlb = 'https://a.espncdn.com/i/teamlogos/mlb/500';
  static const String _espnNhl = 'https://a.espncdn.com/i/teamlogos/nhl/500';
  static const String _espnNcaa = 'https://a.espncdn.com/i/teamlogos/ncaa/500';
  static const String _espnMls = 'https://a.espncdn.com/i/teamlogos/soccer/500';

  /// Map sport display names to league identifiers used internally.
  /// This allows bracket sport fields like "Basketball", "Football" to
  /// resolve to the correct league pool of logos.
  static const Map<String, String> _sportToLeague = {
    // Basketball-related sports → NCAA college basketball
    'basketball': 'ncaa',
    'march madness': 'ncaa',
    'ncaa': 'ncaa',
    'college basketball': 'ncaa',
    'ncaam': 'ncaa',
    'ncaaw': 'ncaa',
    'nba': 'nba',
    // Football-related sports
    'football': 'nfl',
    'nfl': 'nfl',
    'college football': 'ncaaf',
    'cfb': 'ncaaf',
    // Other pro leagues
    'baseball': 'mlb',
    'mlb': 'mlb',
    'hockey': 'nhl',
    'nhl': 'nhl',
    'soccer': 'mls',
    'mls': 'mls',
    // Generic / custom
    'golf': 'golf',
    'tennis': 'tennis',
  };

  /// Resolve sport string → league key.  Returns null if sport is null /
  /// unrecognised (legacy callers without sport context).
  static String? _resolveLeague(String? sport) {
    if (sport == null) return null;
    return _sportToLeague[sport.toLowerCase().trim()];
  }

  /// Get logo URL for a team name.
  ///
  /// * [sport] (optional) – the bracket's sport, e.g. "Basketball" or "Football".
  ///   When provided the lookup is scoped to the correct league pool to
  ///   prevent cross-league logo contamination.
  /// * Returns null if not found.
  static String? getLogoUrl(String teamName, {String? sport}) {
    final clean = teamName
        .replaceAll(RegExp(r'^\(\d+\)\s*'), '')
        .trim()
        .toLowerCase();

    if (clean.isEmpty || clean == 'tbd') return null;

    final league = _resolveLeague(sport);

    // If we know the league, search ONLY that league's map
    if (league != null) {
      final leagueMap = _leagueLogos[league];
      if (leagueMap != null) {
        // Exact match first
        if (leagueMap.containsKey(clean)) return leagueMap[clean];
        // Partial match within the league
        for (final entry in leagueMap.entries) {
          if (clean.contains(entry.key) || entry.key.contains(clean)) {
            return entry.value;
          }
        }
      }
      // League known but no match → return null (don't fallback to other leagues!)
      return null;
    }

    // Legacy path: no sport context → try all leagues but prefer exact matches
    // Try exact match first across all logos
    if (_allLogos.containsKey(clean)) return _allLogos[clean];

    // Partial match (legacy behaviour for callers that don't pass sport)
    for (final entry in _allLogos.entries) {
      if (clean.contains(entry.key) || entry.key.contains(clean)) {
        return entry.value;
      }
    }

    return null;
  }

  /// Check if a team has a logo (league-aware).
  static bool hasLogo(String teamName, {String? sport}) =>
      getLogoUrl(teamName, sport: sport) != null;

  // ═══════════════════════════════════════════════════════════════
  // LEAGUE-SPECIFIC LOGO MAPS
  // ═══════════════════════════════════════════════════════════════

  static final Map<String, Map<String, String>> _leagueLogos = {
    'nfl': _nflLogos,
    'nba': _nbaLogos,
    'mlb': _mlbLogos,
    'nhl': _nhlLogos,
    'mls': _mlsLogos,
    'ncaa': _ncaaLogos,
    'ncaaf': _ncaafLogos,
    'golf': const {},
    'tennis': const {},
  };

  /// Flat lookup for legacy callers (no sport context). Built lazily.
  static Map<String, String>? _flatLogosCache;
  static Map<String, String> get _allLogos {
    if (_flatLogosCache != null) return _flatLogosCache!;
    _flatLogosCache = <String, String>{};
    // Add in priority order: pro leagues first, then college
    for (final map in [
      _nflLogos, _nbaLogos, _mlbLogos, _nhlLogos, _mlsLogos,
      _ncaaLogos, _ncaafLogos,
    ]) {
      for (final entry in map.entries) {
        // Don't overwrite earlier (higher-priority) entries
        _flatLogosCache!.putIfAbsent(entry.key, () => entry.value);
      }
    }
    return _flatLogosCache!;
  }

  // ═══ NFL Teams ═══════════════════════════════════════════
  static final Map<String, String> _nflLogos = {
    'kansas city chiefs': '$_espnNfl/kc.png',
    'chiefs': '$_espnNfl/kc.png',
    'buffalo bills': '$_espnNfl/buf.png',
    'bills': '$_espnNfl/buf.png',
    'baltimore ravens': '$_espnNfl/bal.png',
    'ravens': '$_espnNfl/bal.png',
    'philadelphia eagles': '$_espnNfl/phi.png',
    'eagles': '$_espnNfl/phi.png',
    'san francisco 49ers': '$_espnNfl/sf.png',
    '49ers': '$_espnNfl/sf.png',
    'dallas cowboys': '$_espnNfl/dal.png',
    'cowboys': '$_espnNfl/dal.png',
    'detroit lions': '$_espnNfl/det.png',
    'lions': '$_espnNfl/det.png',
    'miami dolphins': '$_espnNfl/mia.png',
    'dolphins': '$_espnNfl/mia.png',
    'green bay packers': '$_espnNfl/gb.png',
    'packers': '$_espnNfl/gb.png',
    'houston texans': '$_espnNfl/hou.png',
    'texans': '$_espnNfl/hou.png',
    'pittsburgh steelers': '$_espnNfl/pit.png',
    'steelers': '$_espnNfl/pit.png',
    'cincinnati bengals': '$_espnNfl/cin.png',
    'bengals': '$_espnNfl/cin.png',
    'cleveland browns': '$_espnNfl/cle.png',
    'browns': '$_espnNfl/cle.png',
    'jacksonville jaguars': '$_espnNfl/jax.png',
    'jaguars': '$_espnNfl/jax.png',
    'tennessee titans': '$_espnNfl/ten.png',
    'titans': '$_espnNfl/ten.png',
    'indianapolis colts': '$_espnNfl/ind.png',
    'colts': '$_espnNfl/ind.png',
    'las vegas raiders': '$_espnNfl/lv.png',
    'raiders': '$_espnNfl/lv.png',
    'los angeles chargers': '$_espnNfl/lac.png',
    'chargers': '$_espnNfl/lac.png',
    'denver broncos': '$_espnNfl/den.png',
    'broncos': '$_espnNfl/den.png',
    'new york jets': '$_espnNfl/nyj.png',
    'jets': '$_espnNfl/nyj.png',
    'new york giants': '$_espnNfl/nyg.png',
    'giants': '$_espnNfl/nyg.png',
    'new england patriots': '$_espnNfl/ne.png',
    'patriots': '$_espnNfl/ne.png',
    'washington commanders': '$_espnNfl/wsh.png',
    'commanders': '$_espnNfl/wsh.png',
    'seattle seahawks': '$_espnNfl/sea.png',
    'seahawks': '$_espnNfl/sea.png',
    'los angeles rams': '$_espnNfl/lar.png',
    'rams': '$_espnNfl/lar.png',
    'arizona cardinals': '$_espnNfl/ari.png',
    // REMOVED: 'cardinals' shorthand — collides with St. Louis Cardinals (MLB)
    'minnesota vikings': '$_espnNfl/min.png',
    'vikings': '$_espnNfl/min.png',
    'chicago bears': '$_espnNfl/chi.png',
    // REMOVED: 'bears' shorthand — collides with NCAA "Bears" (Baylor)
    'tampa bay buccaneers': '$_espnNfl/tb.png',
    'buccaneers': '$_espnNfl/tb.png',
    'new orleans saints': '$_espnNfl/no.png',
    'saints': '$_espnNfl/no.png',
    'atlanta falcons': '$_espnNfl/atl.png',
    'falcons': '$_espnNfl/atl.png',
    'carolina panthers': '$_espnNfl/car.png',
  };

  // ═══ NBA Teams ═══════════════════════════════════════════
  static final Map<String, String> _nbaLogos = {
    'los angeles lakers': '$_espnNba/lal.png',
    'lakers': '$_espnNba/lal.png',
    'boston celtics': '$_espnNba/bos.png',
    'celtics': '$_espnNba/bos.png',
    'golden state warriors': '$_espnNba/gs.png',
    'warriors': '$_espnNba/gs.png',
    'denver nuggets': '$_espnNba/den.png',
    'nuggets': '$_espnNba/den.png',
    'miami heat': '$_espnNba/mia.png',
    'heat': '$_espnNba/mia.png',
    'milwaukee bucks': '$_espnNba/mil.png',
    'bucks': '$_espnNba/mil.png',
    'philadelphia 76ers': '$_espnNba/phi.png',
    '76ers': '$_espnNba/phi.png',
    'phoenix suns': '$_espnNba/phx.png',
    'suns': '$_espnNba/phx.png',
    'oklahoma city thunder': '$_espnNba/okc.png',
    'thunder': '$_espnNba/okc.png',
    'dallas mavericks': '$_espnNba/dal.png',
    'mavericks': '$_espnNba/dal.png',
    'new york knicks': '$_espnNba/ny.png',
    'knicks': '$_espnNba/ny.png',
    'cleveland cavaliers': '$_espnNba/cle.png',
    'cavaliers': '$_espnNba/cle.png',
    'minnesota timberwolves': '$_espnNba/min.png',
    'timberwolves': '$_espnNba/min.png',
    'sacramento kings': '$_espnNba/sac.png',
    // REMOVED: 'kings' shorthand — collides with NHL LA Kings
    'indiana pacers': '$_espnNba/ind.png',
    'pacers': '$_espnNba/ind.png',
    'chicago bulls': '$_espnNba/chi.png',
    'bulls': '$_espnNba/chi.png',
    'brooklyn nets': '$_espnNba/bkn.png',
    'nets': '$_espnNba/bkn.png',
    'houston rockets': '$_espnNba/hou.png',
    'rockets': '$_espnNba/hou.png',
    'memphis grizzlies': '$_espnNba/mem.png',
    'grizzlies': '$_espnNba/mem.png',
    'new orleans pelicans': '$_espnNba/no.png',
    'pelicans': '$_espnNba/no.png',
    'atlanta hawks': '$_espnNba/atl.png',
    'hawks': '$_espnNba/atl.png',
    'toronto raptors': '$_espnNba/tor.png',
    'raptors': '$_espnNba/tor.png',
    'san antonio spurs': '$_espnNba/sa.png',
    'spurs': '$_espnNba/sa.png',
    'portland trail blazers': '$_espnNba/por.png',
    'trail blazers': '$_espnNba/por.png',
    'orlando magic': '$_espnNba/orl.png',
    'magic': '$_espnNba/orl.png',
    'washington wizards': '$_espnNba/wsh.png',
    'wizards': '$_espnNba/wsh.png',
    'utah jazz': '$_espnNba/utah.png',
    'jazz': '$_espnNba/utah.png',
    'charlotte hornets': '$_espnNba/cha.png',
    'hornets': '$_espnNba/cha.png',
    'detroit pistons': '$_espnNba/det.png',
    'pistons': '$_espnNba/det.png',
    'la clippers': '$_espnNba/lac.png',
    'clippers': '$_espnNba/lac.png',
  };

  // ═══ NCAA College Teams (Basketball + shared) ═══════════
  static final Map<String, String> _ncaaLogos = {
    // ─── Major Basketball Programs ───
    'houston': '$_espnNcaa/248.png',
    'houston cougars': '$_espnNcaa/248.png',
    'duke': '$_espnNcaa/150.png',
    'duke blue devils': '$_espnNcaa/150.png',
    'kansas': '$_espnNcaa/2305.png',
    'kansas jayhawks': '$_espnNcaa/2305.png',
    'uconn': '$_espnNcaa/41.png',
    'connecticut': '$_espnNcaa/41.png',
    'uconn huskies': '$_espnNcaa/41.png',
    'auburn': '$_espnNcaa/2.png',
    'auburn tigers': '$_espnNcaa/2.png',
    'tennessee': '$_espnNcaa/2633.png',
    'tennessee volunteers': '$_espnNcaa/2633.png',
    'gonzaga': '$_espnNcaa/2250.png',
    'gonzaga bulldogs': '$_espnNcaa/2250.png',
    'purdue': '$_espnNcaa/2509.png',
    'purdue boilermakers': '$_espnNcaa/2509.png',
    'alabama': '$_espnNcaa/333.png',
    'alabama crimson tide': '$_espnNcaa/333.png',
    'arizona': '$_espnNcaa/12.png',
    'arizona wildcats': '$_espnNcaa/12.png',
    'north carolina': '$_espnNcaa/153.png',
    'unc': '$_espnNcaa/153.png',
    'tar heels': '$_espnNcaa/153.png',
    'kentucky': '$_espnNcaa/96.png',
    'kentucky wildcats': '$_espnNcaa/96.png',
    'baylor': '$_espnNcaa/239.png',
    'baylor bears': '$_espnNcaa/239.png',
    'villanova': '$_espnNcaa/2918.png',
    'villanova wildcats': '$_espnNcaa/2918.png',
    'michigan st': '$_espnNcaa/127.png',
    'michigan state': '$_espnNcaa/127.png',
    'michigan state spartans': '$_espnNcaa/127.png',
    'florida': '$_espnNcaa/57.png',
    'florida gators': '$_espnNcaa/57.png',
    'iowa st': '$_espnNcaa/66.png',
    'iowa state': '$_espnNcaa/66.png',
    'iowa state cyclones': '$_espnNcaa/66.png',
    'marquette': '$_espnNcaa/269.png',
    'marquette golden eagles': '$_espnNcaa/269.png',
    'wisconsin': '$_espnNcaa/275.png',
    'wisconsin badgers': '$_espnNcaa/275.png',
    'texas tech': '$_espnNcaa/2641.png',
    'texas tech red raiders': '$_espnNcaa/2641.png',
    'indiana': '$_espnNcaa/84.png',
    'indiana hoosiers': '$_espnNcaa/84.png',
    'clemson': '$_espnNcaa/228.png',
    'clemson tigers': '$_espnNcaa/228.png',
    'oregon': '$_espnNcaa/2483.png',
    'oregon ducks': '$_espnNcaa/2483.png',
    'ohio state': '$_espnNcaa/194.png',
    'ohio state buckeyes': '$_espnNcaa/194.png',
    'san diego st': '$_espnNcaa/21.png',
    'san diego state': '$_espnNcaa/21.png',
    'san diego state aztecs': '$_espnNcaa/21.png',
    'michigan': '$_espnNcaa/130.png',
    'michigan wolverines': '$_espnNcaa/130.png',
    'oklahoma': '$_espnNcaa/201.png',
    'oklahoma sooners': '$_espnNcaa/201.png',
    'texas a&m': '$_espnNcaa/245.png',
    'texas a&m aggies': '$_espnNcaa/245.png',
    'creighton': '$_espnNcaa/156.png',
    'creighton bluejays': '$_espnNcaa/156.png',
    'st. johns': '$_espnNcaa/2599.png',
    'st. john\'s': '$_espnNcaa/2599.png',
    'pittsburgh': '$_espnNcaa/221.png',
    'pitt': '$_espnNcaa/221.png',
    'pitt panthers': '$_espnNcaa/221.png',
    'louisville': '$_espnNcaa/97.png',
    'louisville cardinals': '$_espnNcaa/97.png',
    'memphis': '$_espnNcaa/235.png',
    'memphis tigers': '$_espnNcaa/235.png',
    'missouri': '$_espnNcaa/142.png',
    'missouri tigers': '$_espnNcaa/142.png',
    'georgia': '$_espnNcaa/61.png',
    'georgia bulldogs': '$_espnNcaa/61.png',
    'ole miss': '$_espnNcaa/145.png',
    'mississippi': '$_espnNcaa/145.png',
    'texas': '$_espnNcaa/251.png',
    'texas longhorns': '$_espnNcaa/251.png',
    'ucla': '$_espnNcaa/26.png',
    'ucla bruins': '$_espnNcaa/26.png',
    'new mexico': '$_espnNcaa/167.png',
    'new mexico lobos': '$_espnNcaa/167.png',
    'drake': '$_espnNcaa/2181.png',
    'drake bulldogs': '$_espnNcaa/2181.png',
    'yale': '$_espnNcaa/43.png',
    'yale bulldogs': '$_espnNcaa/43.png',
    'vermont': '$_espnNcaa/261.png',
    'vermont catamounts': '$_espnNcaa/261.png',
    'uab': '$_espnNcaa/5.png',
    'furman': '$_espnNcaa/231.png',
    'furman paladins': '$_espnNcaa/231.png',
    'princeton': '$_espnNcaa/163.png',
    'princeton tigers': '$_espnNcaa/163.png',
    'uc irvine': '$_espnNcaa/300.png',
    'james madison': '$_espnNcaa/256.png',
    'james madison dukes': '$_espnNcaa/256.png',
    'fau': '$_espnNcaa/2226.png',
    'florida atlantic': '$_espnNcaa/2226.png',
    'charleston': '$_espnNcaa/232.png',
    'siu-e': '$_espnNcaa/2565.png',
    'colgate': '$_espnNcaa/2142.png',
    'utah st': '$_espnNcaa/328.png',
    'utah state': '$_espnNcaa/328.png',
    'long beach st': '$_espnNcaa/299.png',
    'long beach state': '$_espnNcaa/299.png',
    'stetson': '$_espnNcaa/56.png',
    'tulane': '$_espnNcaa/2655.png',
    'miami': '$_espnNcaa/2390.png', // University of Miami
    'miami hurricanes': '$_espnNcaa/2390.png',
    'xavier': '$_espnNcaa/2752.png',
    'st. marys': '$_espnNcaa/2608.png',
    'dayton': '$_espnNcaa/2168.png',
    'boise state': '$_espnNcaa/68.png',
    'boise st': '$_espnNcaa/68.png',
    'colorado state': '$_espnNcaa/36.png',
    'colorado': '$_espnNcaa/38.png',
    'vcu': '$_espnNcaa/2670.png',
    'nebraska': '$_espnNcaa/158.png',
    'grand canyon': '$_espnNcaa/2253.png',
    'nevada': '$_espnNcaa/2440.png',
    'loyola chicago': '$_espnNcaa/2350.png',
    'oral roberts': '$_espnNcaa/198.png',
    'wichita st': '$_espnNcaa/2724.png',
    'wichita state': '$_espnNcaa/2724.png',
  };

  // ═══ NCAA Football (College Football Playoff) ═══════════
  static final Map<String, String> _ncaafLogos = {
    // Reuse the same NCAA ESPN IDs — the URL pattern works for both
    'ohio state': '$_espnNcaa/194.png',
    'alabama': '$_espnNcaa/333.png',
    'georgia': '$_espnNcaa/61.png',
    'clemson': '$_espnNcaa/228.png',
    'michigan': '$_espnNcaa/130.png',
    'texas': '$_espnNcaa/251.png',
    'oregon': '$_espnNcaa/2483.png',
    'penn state': '$_espnNcaa/213.png',
    'notre dame': '$_espnNcaa/87.png',
    'florida state': '$_espnNcaa/52.png',
    'lsu': '$_espnNcaa/99.png',
    'usc': '$_espnNcaa/30.png',
    'washington': '$_espnNcaa/264.png',
    'tennessee': '$_espnNcaa/2633.png',
    'oklahoma': '$_espnNcaa/201.png',
    'boise state': '$_espnNcaa/68.png',
    'boise st': '$_espnNcaa/68.png',
    'smu': '$_espnNcaa/2567.png',
    'arizona state': '$_espnNcaa/9.png',
    'indiana': '$_espnNcaa/84.png',
  };

  // ═══ MLB Teams ═══════════════════════════════════════════
  static final Map<String, String> _mlbLogos = {
    'new york yankees': '$_espnMlb/nyy.png',
    'yankees': '$_espnMlb/nyy.png',
    'los angeles dodgers': '$_espnMlb/lad.png',
    'dodgers': '$_espnMlb/lad.png',
    'houston astros': '$_espnMlb/hou.png',
    'astros': '$_espnMlb/hou.png',
    'atlanta braves': '$_espnMlb/atl.png',
    'braves': '$_espnMlb/atl.png',
    'texas rangers': '$_espnMlb/tex.png',
    // REMOVED: 'rangers' shorthand — collides with NHL NY Rangers
    'philadelphia phillies': '$_espnMlb/phi.png',
    'phillies': '$_espnMlb/phi.png',
    'arizona diamondbacks': '$_espnMlb/ari.png',
    'diamondbacks': '$_espnMlb/ari.png',
    'minnesota twins': '$_espnMlb/min.png',
    'twins': '$_espnMlb/min.png',
    'tampa bay rays': '$_espnMlb/tb.png',
    'rays': '$_espnMlb/tb.png',
    'boston red sox': '$_espnMlb/bos.png',
    'red sox': '$_espnMlb/bos.png',
    'chicago cubs': '$_espnMlb/chc.png',
    'cubs': '$_espnMlb/chc.png',
    'san francisco giants': '$_espnMlb/sf.png',
    'st. louis cardinals': '$_espnMlb/stl.png',
    'san diego padres': '$_espnMlb/sd.png',
    'padres': '$_espnMlb/sd.png',
    'new york mets': '$_espnMlb/nym.png',
    'mets': '$_espnMlb/nym.png',
    'seattle mariners': '$_espnMlb/sea.png',
    'mariners': '$_espnMlb/sea.png',
    'detroit tigers': '$_espnMlb/det.png',
    // REMOVED: 'tigers' shorthand — collides with NCAA (Auburn, Clemson, etc.)
    'baltimore orioles': '$_espnMlb/bal.png',
    'orioles': '$_espnMlb/bal.png',
    'cleveland guardians': '$_espnMlb/cle.png',
    'guardians': '$_espnMlb/cle.png',
    'milwaukee brewers': '$_espnMlb/mil.png',
    'brewers': '$_espnMlb/mil.png',
    'pittsburgh pirates': '$_espnMlb/pit.png',
    'pirates': '$_espnMlb/pit.png',
    'kansas city royals': '$_espnMlb/kc.png',
    'royals': '$_espnMlb/kc.png',
    'cincinnati reds': '$_espnMlb/cin.png',
    'reds': '$_espnMlb/cin.png',
    'chicago white sox': '$_espnMlb/chw.png',
    'white sox': '$_espnMlb/chw.png',
  };

  // ═══ NHL Teams ═══════════════════════════════════════════
  static final Map<String, String> _nhlLogos = {
    'florida panthers': '$_espnNhl/fla.png',
    // REMOVED: 'panthers' shorthand — collides with NFL Carolina Panthers
    'edmonton oilers': '$_espnNhl/edm.png',
    'oilers': '$_espnNhl/edm.png',
    'new york rangers': '$_espnNhl/nyr.png',
    'dallas stars': '$_espnNhl/dal.png',
    'stars': '$_espnNhl/dal.png',
    'colorado avalanche': '$_espnNhl/col.png',
    'avalanche': '$_espnNhl/col.png',
    'boston bruins': '$_espnNhl/bos.png',
    'bruins': '$_espnNhl/bos.png',
    'carolina hurricanes': '$_espnNhl/car.png',
    'hurricanes': '$_espnNhl/car.png',
    'vancouver canucks': '$_espnNhl/van.png',
    'canucks': '$_espnNhl/van.png',
    'winnipeg jets': '$_espnNhl/wpg.png',
    'tampa bay lightning': '$_espnNhl/tb.png',
    'lightning': '$_espnNhl/tb.png',
    'nashville predators': '$_espnNhl/nsh.png',
    'predators': '$_espnNhl/nsh.png',
    'toronto maple leafs': '$_espnNhl/tor.png',
    'maple leafs': '$_espnNhl/tor.png',
    'vegas golden knights': '$_espnNhl/vgk.png',
    'golden knights': '$_espnNhl/vgk.png',
    'pittsburgh penguins': '$_espnNhl/pit.png',
    'penguins': '$_espnNhl/pit.png',
    'washington capitals': '$_espnNhl/wsh.png',
    'capitals': '$_espnNhl/wsh.png',
    'detroit red wings': '$_espnNhl/det.png',
    'red wings': '$_espnNhl/det.png',
    'minnesota wild': '$_espnNhl/min.png',
    'wild': '$_espnNhl/min.png',
    'los angeles kings': '$_espnNhl/la.png',
    'st. louis blues': '$_espnNhl/stl.png',
    'blues': '$_espnNhl/stl.png',
    'chicago blackhawks': '$_espnNhl/chi.png',
    'blackhawks': '$_espnNhl/chi.png',
    'new jersey devils': '$_espnNhl/nj.png',
    'devils': '$_espnNhl/nj.png',
    'ottawa senators': '$_espnNhl/ott.png',
    'senators': '$_espnNhl/ott.png',
    'philadelphia flyers': '$_espnNhl/phi.png',
    'flyers': '$_espnNhl/phi.png',
    'montreal canadiens': '$_espnNhl/mtl.png',
    'canadiens': '$_espnNhl/mtl.png',
    'calgary flames': '$_espnNhl/cgy.png',
    'flames': '$_espnNhl/cgy.png',
    'seattle kraken': '$_espnNhl/sea.png',
    'kraken': '$_espnNhl/sea.png',
    'new york islanders': '$_espnNhl/nyi.png',
    'islanders': '$_espnNhl/nyi.png',
    'san jose sharks': '$_espnNhl/sj.png',
    'sharks': '$_espnNhl/sj.png',
    'buffalo sabres': '$_espnNhl/buf.png',
    'sabres': '$_espnNhl/buf.png',
    'columbus blue jackets': '$_espnNhl/cbj.png',
    'blue jackets': '$_espnNhl/cbj.png',
    'anaheim ducks': '$_espnNhl/ana.png',
    'ducks': '$_espnNhl/ana.png',
    'arizona coyotes': '$_espnNhl/ari.png',
    'coyotes': '$_espnNhl/ari.png',
  };

  // ═══ MLS Teams ═══════════════════════════════════════════
  static final Map<String, String> _mlsLogos = {
    'inter miami': '$_espnMls/12396.png',
    'lafc': '$_espnMls/8524.png',
    'columbus crew': '$_espnMls/300.png',
    'fc cincinnati': '$_espnMls/11504.png',
    'atlanta united': '$_espnMls/9002.png',
    'seattle sounders': '$_espnMls/9726.png',
    'nashville sc': '$_espnMls/14072.png',
    'houston dynamo': '$_espnMls/399.png',
    'portland timbers': '$_espnMls/9498.png',
    'la galaxy': '$_espnMls/213.png',
    'galaxy': '$_espnMls/213.png',
    'new york red bulls': '$_espnMls/399.png',
    'red bulls': '$_espnMls/399.png',
    'new york city fc': '$_espnMls/9668.png',
    'nycfc': '$_espnMls/9668.png',
    'sporting kansas city': '$_espnMls/311.png',
    'austin fc': '$_espnMls/15296.png',
    'real salt lake': '$_espnMls/2832.png',
    'minnesota united': '$_espnMls/9958.png',
    'cf montreal': '$_espnMls/243.png',
    'toronto fc': '$_espnMls/2762.png',
    'vancouver whitecaps': '$_espnMls/9727.png',
    'colorado rapids': '$_espnMls/176.png',
    'san jose earthquakes': '$_espnMls/218.png',
    'fc dallas': '$_espnMls/193.png',
    'chicago fire': '$_espnMls/167.png',
    'charlotte fc': '$_espnMls/17362.png',
    'dc united': '$_espnMls/184.png',
    'new england revolution': '$_espnMls/928.png',
    'orlando city': '$_espnMls/9958.png',
    'philadelphia union': '$_espnMls/8090.png',
    'st. louis city sc': '$_espnMls/18798.png',
    'san diego fc': '$_espnMls/18798.png',
  };
}
