// ─── SVG BRACKET TEMPLATE GENERATOR ─────────────────────────────────────────
// Generates publication-quality SVG bracket templates for 4, 8, 16, 32, 64
// team single-elimination tournaments.
//
// Each SVG contains:
// - Named slot elements (id="slot_rX_mY_teamN") for pick injection
// - Connector lines between rounds
// - Round / region headers
// - BMB "B" logo watermark at center
// - "BACKMYBRACKET.COM" footer branding
// - Championship / Final matchup area
//
// Layout: left-side bracket (top half) + right-side bracket (bottom half)
//         converging to a center championship matchup.

class SvgBracketGenerator {
  // ─── BMB Brand Palette ──────────────────────────────────────────────────
  static const _bgColor = '#0A0E27'; // deepNavy
  static const _cardColor = '#1A2244'; // cardGradientStart
  static const _cardBorder = '#2A3260'; // borderColor
  static const _lineColor = '#3D4376'; // greyBlue
  static const _lineHighlight = '#2137FF'; // blue
  static const _goldColor = '#FFD700'; // gold
  static const _textPrimary = '#FFFFFF';
  // ignore: unused_field
  static const _textSecondary = '#B0B8D4';
  static const _textTertiary = '#7A82A1';
  static const _seedColor = '#FFD700'; // gold for seed numbers
  static const _logoRed = '#D63031'; // BMB red (from splash_dark)
  static const _slotBg = '#252949'; // cardDark
  // ignore: unused_field
  static const _slotBgHover = '#2A3260';

  /// Generate SVG string for a bracket of [teamCount] teams.
  /// [title] is the bracket name shown at top.
  /// [teams] is an optional list of team names; null slots render as "TBD".
  /// [showSeeds] adds seed numbers (#1, #2, etc.) beside team names.
  static String generate({
    required int teamCount,
    String title = 'TOURNAMENT BRACKET',
    List<String>? teams,
    bool showSeeds = true,
  }) {
    assert([4, 8, 16, 32, 64].contains(teamCount),
        'teamCount must be 4, 8, 16, 32, or 64');

    final rounds = _roundCount(teamCount);
    final halfTeams = teamCount ~/ 2;

    // ── Canvas sizing ────────────────────────────────────────────────
    // Layout is landscape: left bracket → center championship ← right bracket
    final slotW = teamCount <= 8 ? 180.0 : teamCount <= 16 ? 160.0 : 140.0;
    final slotH = teamCount <= 16 ? 32.0 : 26.0;
    final matchGap = teamCount <= 8 ? 16.0 : teamCount <= 16 ? 12.0 : 8.0;
    final roundGap = teamCount <= 8 ? 60.0 : teamCount <= 16 ? 48.0 : 36.0;
    final headerH = 70.0;
    final footerH = 50.0;

    final halfRounds = rounds ~/ 2 + (rounds.isOdd ? 1 : 0);
    // Width: left bracket rounds + championship zone + right bracket rounds
    final champW = slotW + 40;
    final sideW = halfRounds * (slotW + roundGap);
    final canvasW = sideW + champW + sideW + 80; // 40px margin each side
    // Height: whichever side has more first-round matches
    final firstRoundMatches = halfTeams ~/ 2;
    final matchH = slotH * 2 + matchGap;
    final bracketContentH = firstRoundMatches * matchH + (firstRoundMatches - 1) * matchGap;
    final canvasH = headerH + bracketContentH + footerH + 60;

    final buf = StringBuffer();

    // ── SVG root ─────────────────────────────────────────────────────
    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 $canvasW $canvasH" '
        'width="$canvasW" height="$canvasH" '
        'style="background:$_bgColor" '
        'font-family="\'ClashDisplay\', \'Inter\', \'Segoe UI\', sans-serif">');

    // ── Defs: gradients, filters ────────────────────────────────────
    buf.writeln('<defs>');
    buf.writeln('  <linearGradient id="cardGrad" x1="0" y1="0" x2="1" y2="1">');
    buf.writeln('    <stop offset="0%" stop-color="#1A2244"/>');
    buf.writeln('    <stop offset="100%" stop-color="#252D5A"/>');
    buf.writeln('  </linearGradient>');
    buf.writeln('  <linearGradient id="goldGrad" x1="0" y1="0" x2="1" y2="0">');
    buf.writeln('    <stop offset="0%" stop-color="#FFD700"/>');
    buf.writeln('    <stop offset="100%" stop-color="#FFE44D"/>');
    buf.writeln('  </linearGradient>');
    buf.writeln('  <linearGradient id="champGrad" x1="0" y1="0" x2="0" y2="1">');
    buf.writeln('    <stop offset="0%" stop-color="#FFD700" stop-opacity="0.2"/>');
    buf.writeln('    <stop offset="100%" stop-color="#0A0E27" stop-opacity="0"/>');
    buf.writeln('  </linearGradient>');
    buf.writeln('  <filter id="glow">');
    buf.writeln('    <feGaussianBlur stdDeviation="3" result="blur"/>');
    buf.writeln('    <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>');
    buf.writeln('  </filter>');
    buf.writeln('</defs>');

    // ── Background pattern (subtle grid) ────────────────────────────
    buf.writeln('<rect width="$canvasW" height="$canvasH" fill="$_bgColor"/>');
    // Subtle grid lines
    for (double x = 0; x < canvasW; x += 40) {
      buf.writeln('<line x1="$x" y1="0" x2="$x" y2="$canvasH" stroke="$_cardBorder" stroke-opacity="0.15" stroke-width="0.5"/>');
    }
    for (double y = 0; y < canvasH; y += 40) {
      buf.writeln('<line x1="0" y1="$y" x2="$canvasW" y2="$y" stroke="$_cardBorder" stroke-opacity="0.15" stroke-width="0.5"/>');
    }

    // ── Header ──────────────────────────────────────────────────────
    _writeHeader(buf, canvasW, title, teamCount);

    // ── Center logo watermark ───────────────────────────────────────
    final cx = canvasW / 2;
    final cy = headerH + bracketContentH / 2;
    _writeLogo(buf, cx, cy, teamCount <= 8 ? 100 : 80);

    // ── LEFT BRACKET (top seeds) ────────────────────────────────────
    final leftX = 40.0;
    final bracketY = headerH + 20;
    final leftRounds = (rounds + 1) ~/ 2; // rounds feeding into the left finalist
    _writeBracketSide(
      buf,
      side: 'left',
      startX: leftX,
      startY: bracketY,
      teamCount: halfTeams,
      totalRounds: leftRounds,
      slotW: slotW,
      slotH: slotH,
      matchGap: matchGap,
      roundGap: roundGap,
      teams: teams?.sublist(0, halfTeams),
      showSeeds: showSeeds,
      seedOffset: 0,
    );

    // ── RIGHT BRACKET (bottom seeds) ────────────────────────────────
    final rightX = canvasW - 40;
    _writeBracketSide(
      buf,
      side: 'right',
      startX: rightX,
      startY: bracketY,
      teamCount: halfTeams,
      totalRounds: leftRounds,
      slotW: slotW,
      slotH: slotH,
      matchGap: matchGap,
      roundGap: roundGap,
      teams: teams?.sublist(halfTeams),
      showSeeds: showSeeds,
      seedOffset: halfTeams,
    );

    // ── CHAMPIONSHIP (center) ───────────────────────────────────────
    _writeChampionship(buf, cx, cy, slotW, slotH, teamCount);

    // ── Footer ──────────────────────────────────────────────────────
    _writeFooter(buf, canvasW, canvasH);

    buf.writeln('</svg>');
    return buf.toString();
  }

  // ════════════════════════════════════════════════════════════════════════
  // PRIVATE HELPERS
  // ════════════════════════════════════════════════════════════════════════

  static int _roundCount(int teamCount) {
    int n = teamCount, r = 0;
    while (n > 1) { n ~/= 2; r++; }
    return r;
  }

  static List<String> _roundNames(int totalRounds) {
    // Names from the final backwards
    final names = <String>[];
    for (int i = 0; i < totalRounds; i++) {
      if (i == 0) {
        names.add('CHAMPIONSHIP');
      } else if (i == 1) {
        names.add('SEMI-FINALS');
      } else if (i == 2) {
        names.add('QUARTER-FINALS');
      } else {
        names.add('ROUND ${totalRounds - i}');
      }
    }
    return names.reversed.toList();
  }

  // ─── HEADER ──────────────────────────────────────────────────────────
  static void _writeHeader(StringBuffer buf, double canvasW, String title, int teamCount) {
    final cx = canvasW / 2;
    // Background bar
    buf.writeln('<rect x="0" y="0" width="$canvasW" height="65" fill="$_cardColor" opacity="0.8"/>');
    buf.writeln('<line x1="0" y1="65" x2="$canvasW" y2="65" stroke="$_goldColor" stroke-width="2" opacity="0.6"/>');
    // Title
    buf.writeln('<text x="$cx" y="30" text-anchor="middle" fill="$_textPrimary" '
        'font-size="20" font-weight="700" letter-spacing="2">$title</text>');
    // Subtitle
    buf.writeln('<text x="$cx" y="50" text-anchor="middle" fill="$_goldColor" '
        'font-size="12" font-weight="600" letter-spacing="3">'
        '$teamCount-TEAM SINGLE ELIMINATION</text>');
  }

  // ─── FOOTER ──────────────────────────────────────────────────────────
  static void _writeFooter(StringBuffer buf, double canvasW, double canvasH) {
    final cx = canvasW / 2;
    final fy = canvasH - 30;
    buf.writeln('<line x1="0" y1="${canvasH - 50}" x2="$canvasW" y2="${canvasH - 50}" '
        'stroke="$_goldColor" stroke-width="1" opacity="0.3"/>');
    buf.writeln('<text x="$cx" y="$fy" text-anchor="middle" fill="$_textTertiary" '
        'font-size="11" font-weight="600" letter-spacing="4">'
        'BACKMYBRACKET.COM</text>');
    // Small logo mark left
    buf.writeln('<text x="20" y="$fy" fill="$_logoRed" font-size="14" font-weight="700">BMB</text>');
    // TM
    buf.writeln('<text x="${canvasW - 30}" y="$fy" fill="$_textTertiary" font-size="8">TM</text>');
  }

  // ─── LOGO WATERMARK ─────────────────────────────────────────────────
  static void _writeLogo(StringBuffer buf, double cx, double cy, double size) {
    // Stylized "B" watermark — simplified vector path resembling the BMB mark
    final s = size;
    final x = cx - s / 2;
    final y = cy - s / 2;
    buf.writeln('<g opacity="0.08" transform="translate($x, $y)">');
    // Outer B shape
    buf.writeln('  <path d="'
        'M${s * 0.15},${s * 0.1} '
        'L${s * 0.65},${s * 0.1} '
        'Q${s * 0.85},${s * 0.1} ${s * 0.85},${s * 0.3} '
        'Q${s * 0.85},${s * 0.45} ${s * 0.65},${s * 0.5} '
        'Q${s * 0.9},${s * 0.55} ${s * 0.9},${s * 0.72} '
        'Q${s * 0.9},${s * 0.9} ${s * 0.65},${s * 0.9} '
        'L${s * 0.15},${s * 0.9} Z'
        '" fill="$_logoRed"/>');
    // Inner cutouts
    buf.writeln('  <rect x="${s * 0.3}" y="${s * 0.22}" width="${s * 0.25}" height="${s * 0.16}" rx="3" fill="$_bgColor"/>');
    buf.writeln('  <rect x="${s * 0.3}" y="${s * 0.58}" width="${s * 0.3}" height="${s * 0.2}" rx="3" fill="$_bgColor"/>');
    buf.writeln('</g>');
  }

  // ─── BRACKET SIDE ───────────────────────────────────────────────────
  static void _writeBracketSide(
    StringBuffer buf, {
    required String side,
    required double startX,
    required double startY,
    required int teamCount,
    required int totalRounds,
    required double slotW,
    required double slotH,
    required double matchGap,
    required double roundGap,
    required List<String>? teams,
    required bool showSeeds,
    required int seedOffset,
  }) {
    final isLeft = side == 'left';
    final rounds = _roundCount(teamCount * 2); // rounds for this side only
    final sideRounds = totalRounds;
    final roundLabels = _roundNames(rounds + 1); // +1 for championship

    int matchesInRound = teamCount ~/ 2;
    final matchH = slotH * 2 + matchGap;

    for (int r = 0; r < sideRounds; r++) {
      // Round label
      final roundLabelX = isLeft
          ? startX + r * (slotW + roundGap) + slotW / 2
          : startX - r * (slotW + roundGap) - slotW / 2;
      if (r < roundLabels.length) {
        buf.writeln('<text x="$roundLabelX" y="${startY - 6}" text-anchor="middle" '
            'fill="$_textTertiary" font-size="9" font-weight="600" letter-spacing="1.5">'
            '${roundLabels[r]}</text>');
      }

      // Vertical spacing: each subsequent round's matches are centered between previous round's
      final totalH = matchesInRound * matchH + (matchesInRound - 1) * matchGap;
      final firstMatchOffset = (startY + ((teamCount ~/ 2) * matchH + ((teamCount ~/ 2) - 1) * matchGap) / 2) - totalH / 2;

      for (int m = 0; m < matchesInRound; m++) {
        final myCenterY = firstMatchOffset + m * (matchH + matchGap) + matchH / 2;
        final slotX = isLeft
            ? startX + r * (slotW + roundGap)
            : startX - r * (slotW + roundGap) - slotW;

        // Top team slot
        final topY = myCenterY - slotH - matchGap / 2;
        final topId = 'slot_${side}_r${r}_m${m}_team1';
        String topLabel = 'TBD';
        String topSeed = '';
        if (r == 0 && teams != null) {
          final idx = m * 2;
          if (idx < teams.length) topLabel = teams[idx];
          if (showSeeds) topSeed = '#${seedOffset + idx + 1}';
        }
        _writeSlot(buf, slotX, topY, slotW, slotH, topId, topLabel, topSeed, r == 0);

        // Bottom team slot
        final botY = myCenterY + matchGap / 2;
        final botId = 'slot_${side}_r${r}_m${m}_team2';
        String botLabel = 'TBD';
        String botSeed = '';
        if (r == 0 && teams != null) {
          final idx = m * 2 + 1;
          if (idx < teams.length) botLabel = teams[idx];
          if (showSeeds) botSeed = '#${seedOffset + idx + 1}';
        }
        _writeSlot(buf, slotX, botY, slotW, slotH, botId, botLabel, botSeed, r == 0);

        // Connector line between top and bottom (vertical bar on the winning side)
        final connX = isLeft ? slotX + slotW : slotX;
        buf.writeln('<line x1="$connX" y1="${topY + slotH / 2}" x2="$connX" y2="${botY + slotH / 2}" '
            'stroke="$_lineColor" stroke-width="1.5"/>');

        // Horizontal connector to next round
        if (r < sideRounds - 1) {
          final hLineY = myCenterY;
          final hLineEndX = isLeft
              ? slotX + slotW + roundGap / 2
              : slotX - roundGap / 2;
          buf.writeln('<line x1="$connX" y1="$hLineY" x2="$hLineEndX" y2="$hLineY" '
              'stroke="$_lineColor" stroke-width="1.5"/>');
        } else {
          // Final connector going toward championship
          final hLineY = myCenterY;
          final hLineEndX = isLeft
              ? slotX + slotW + roundGap * 0.8
              : slotX - roundGap * 0.8;
          buf.writeln('<line x1="$connX" y1="$hLineY" x2="$hLineEndX" y2="$hLineY" '
              'stroke="$_goldColor" stroke-width="2" opacity="0.6"/>');
        }
      }

      matchesInRound = (matchesInRound / 2).ceil();
      if (matchesInRound < 1) matchesInRound = 1;
    }
  }

  // ─── SINGLE TEAM SLOT ──────────────────────────────────────────────
  static void _writeSlot(
    StringBuffer buf,
    double x, double y,
    double w, double h,
    String id,
    String label,
    String seed,
    bool isFirstRound,
  ) {
    final rx = 6.0;
    // Slot background
    buf.writeln('<g id="$id">');
    buf.writeln('  <rect x="$x" y="$y" width="$w" height="$h" rx="$rx" '
        'fill="$_slotBg" stroke="$_cardBorder" stroke-width="1"/>');
    // Seed badge (left side)
    if (seed.isNotEmpty && isFirstRound) {
      buf.writeln('  <rect x="$x" y="$y" width="28" height="$h" rx="$rx" '
          'fill="$_lineHighlight" opacity="0.2"/>');
      // Clip the right corners of the seed badge
      buf.writeln('  <rect x="${x + 14}" y="$y" width="14" height="$h" '
          'fill="$_lineHighlight" opacity="0.2"/>');
      buf.writeln('  <text x="${x + 14}" y="${y + h / 2 + 4}" text-anchor="middle" '
          'fill="$_seedColor" font-size="9" font-weight="700">$seed</text>');
    }
    // Team name
    final textX = isFirstRound && seed.isNotEmpty ? x + 34 : x + 10;
    final maxLabelLen = isFirstRound ? 16 : 14;
    final displayLabel = label.length > maxLabelLen
        ? '${label.substring(0, maxLabelLen - 1)}..'
        : label;
    buf.writeln('  <text x="$textX" y="${y + h / 2 + 4}" fill="${label == 'TBD' ? _textTertiary : _textPrimary}" '
        'font-size="${h > 28 ? 12 : 10}" font-weight="${label == 'TBD' ? '400' : '600'}">'
        '$displayLabel</text>');
    // Score area (right side)
    buf.writeln('  <rect x="${x + w - 36}" y="$y" width="36" height="$h" rx="$rx" '
        'fill="$_cardBorder" opacity="0.4"/>');
    buf.writeln('  <text id="${id}_score" x="${x + w - 18}" y="${y + h / 2 + 4}" text-anchor="middle" '
        'fill="$_textTertiary" font-size="10" font-weight="700">—</text>');
    buf.writeln('</g>');
  }

  // ─── CHAMPIONSHIP CENTER ──────────────────────────────────────────
  static void _writeChampionship(
    StringBuffer buf,
    double cx, double cy,
    double slotW, double slotH,
    int teamCount,
  ) {
    final champW = slotW + 40;
    final champH = slotH * 3 + 60;
    final x = cx - champW / 2;
    final y = cy - champH / 2;

    // Glow effect
    buf.writeln('<rect x="${x - 4}" y="${y - 4}" width="${champW + 8}" height="${champH + 8}" '
        'rx="18" fill="none" stroke="$_goldColor" stroke-width="1" opacity="0.2" filter="url(#glow)"/>');

    // Championship box
    buf.writeln('<rect x="$x" y="$y" width="$champW" height="$champH" rx="16" '
        'fill="url(#cardGrad)" stroke="$_goldColor" stroke-width="2" opacity="0.9"/>');

    // Trophy icon area
    buf.writeln('<text x="$cx" y="${y + 24}" text-anchor="middle" fill="$_goldColor" '
        'font-size="20">&#x1F3C6;</text>');
    buf.writeln('<text x="$cx" y="${y + 42}" text-anchor="middle" fill="$_goldColor" '
        'font-size="10" font-weight="700" letter-spacing="2">CHAMPIONSHIP</text>');

    // Left finalist slot
    final fSlotW = champW - 20;
    final fSlotH = slotH;
    final fSlotX = cx - fSlotW / 2;
    final fSlotY1 = y + 52;
    _writeSlot(buf, fSlotX, fSlotY1, fSlotW, fSlotH, 'slot_champ_team1', 'TBD', '', false);

    // VS
    buf.writeln('<text x="$cx" y="${fSlotY1 + fSlotH + 16}" text-anchor="middle" fill="$_textTertiary" '
        'font-size="11" font-weight="700">VS</text>');

    // Right finalist slot
    final fSlotY2 = fSlotY1 + fSlotH + 24;
    _writeSlot(buf, fSlotX, fSlotY2, fSlotW, fSlotH, 'slot_champ_team2', 'TBD', '', false);

    // Winner line
    final winnerY = fSlotY2 + fSlotH + 20;
    buf.writeln('<line x1="${cx - 40}" y1="$winnerY" x2="${cx + 40}" y2="$winnerY" '
        'stroke="url(#goldGrad)" stroke-width="2"/>');
    buf.writeln('<text x="$cx" y="${winnerY + 16}" text-anchor="middle" fill="$_goldColor" '
        'font-size="10" font-weight="700" letter-spacing="1.5">CHAMPION</text>');
    // Winner name placeholder
    buf.writeln('<text id="slot_champion" x="$cx" y="${winnerY + 32}" text-anchor="middle" '
        'fill="$_textPrimary" font-size="13" font-weight="700">TBD</text>');
  }

  // ════════════════════════════════════════════════════════════════════════
  // CONVENIENCE: Generate all 5 sizes
  // ════════════════════════════════════════════════════════════════════════

  static Map<int, String> generateAll({String title = 'TOURNAMENT BRACKET'}) {
    return {
      for (final size in [4, 8, 16, 32, 64])
        size: generate(teamCount: size, title: title),
    };
  }
}
