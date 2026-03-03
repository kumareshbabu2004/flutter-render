import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';

/// Canonical entry point: outputs a clean, print-safe SVG string.
///
/// This is the SOLE source of truth for both:
///   1. Print-ready files delivered to the DTG printer.
///   2. Preview overlays rasterised onto the garment mockup.
///
/// The function:
///   - **Asserts [bracketData] was produced by [sanitizeBracketForPrint].**
///   - Logs the render path with CANONICAL_ONLY=true.
///   - Enforces portrait-only layout.
///   - Runs the UI contamination check on the palette (exact, alpha-aware,
///     and HSV-range).
///   - Ensures all colours are RGB.
///   - Validates the output SVG contains no banned UI hex colours or
///     banned class-name patterns ("highlight", "selected", "hover", etc.).
///   - Writes debug artifacts to /tmp/debug/ when PREVIEW_DEBUG=true.
///
/// Throws [PreviewUiLayerDetected] if any guard fails.
/// After sanitization, guards should NEVER fire — if they do, it is a
/// **fatal bug** in the sanitizer or palette logic.
///
/// In a server context the caller MUST return HTTP 500 with body
/// `PREVIEW_UI_LAYER_DETECTED`.
String renderBracketPrintSvg(
  BracketPrintData bracketData,
  ProductPrintConfig productConfig,
) {
  // ── Log canonical path ─────────────────────────────────────
  CanonicalRendererLog.log('renderBracketPrintSvg');

  // ── Guard: data must be sanitized ──────────────────────────
  UiContaminationGuard.assertSanitized(bracketData);

  // ── Guard: post-sanitization palette + data clean ──────────
  // After sanitization this MUST pass. If it throws, treat as fatal.
  UiContaminationGuard.assertPostSanitizationClean(
    bracketData, productConfig.palette);

  // ── Render SVG ────────────────────────────────────────────
  final svg = BracketPrintRenderer.render(
    teamCount: bracketData.teamCount,
    bracketTitle: bracketData.bracketTitle,
    championName: bracketData.championName,
    picks: bracketData.picks,
    teams: bracketData.teams,
    palette: productConfig.palette,
    style: bracketData.style,
    transparent: true, // garment overlay → transparent background
    showSeeds: true,
  );

  // ── Guard: output SVG clean (hex + regex class names) ──────
  UiContaminationGuard.assertCleanSvg(svg);

  // ── Debug artifacts ────────────────────────────────────────
  if (isPreviewDebugEnabled) {
    _writeDebugSvg(svg);
  }

  return svg;
}

/// FIX #5: Removed dart:io — web-safe. Debug SVG is logged to console only.
void _writeDebugSvg(String svg) {
  if (kDebugMode) {
    debugPrint('[DebugArtifact] SVG rendered (${svg.length} bytes)');
  }
}

/// Generates print-ready SVG bracket art in 3 styles, color-aware.
/// The bracket title and champion are pulled from the user's actual bracket data.
///
/// **Prefer calling [renderBracketPrintSvg] instead of this class directly.**
/// The top-level function wraps the renderer with contamination and layout guards.
class BracketPrintRenderer {
  /// Generate a print-ready SVG bracket.
  /// [palette] determines colors based on garment darkness.
  /// [style] is Classic, Premium, or Bold.
  /// [transparent] true = no background (for garment overlay).
  static String render({
    required int teamCount,
    required String bracketTitle,
    required String championName,
    required Map<String, String> picks,
    required List<String> teams,
    required BracketPrintPalette palette,
    BracketPrintStyle style = BracketPrintStyle.classic,
    bool transparent = true,
    bool showSeeds = true,
  }) {
    switch (style) {
      case BracketPrintStyle.classic:
        return _renderClassic(
          teamCount: teamCount,
          bracketTitle: bracketTitle,
          championName: championName,
          picks: picks,
          teams: teams,
          palette: palette,
          transparent: transparent,
          showSeeds: showSeeds,
        );
      case BracketPrintStyle.premium:
        return _renderPremium(
          teamCount: teamCount,
          bracketTitle: bracketTitle,
          championName: championName,
          picks: picks,
          teams: teams,
          palette: palette,
          transparent: transparent,
          showSeeds: showSeeds,
        );
      case BracketPrintStyle.bold:
        return _renderBold(
          teamCount: teamCount,
          bracketTitle: bracketTitle,
          championName: championName,
          picks: picks,
          teams: teams,
          palette: palette,
          transparent: transparent,
          showSeeds: showSeeds,
        );
    }
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED LAYOUT ENGINE
  // ════════════════════════════════════════════════════════════════════

  static int _roundCount(int n) {
    int r = 0;
    while (n > 1) { n ~/= 2; r++; }
    return r;
  }

  static _LayoutParams _computeLayout(int teamCount) {
    final rounds = _roundCount(teamCount);
    final halfTeams = teamCount ~/ 2;

    final slotW = teamCount <= 8 ? 170.0 : teamCount <= 16 ? 150.0 : 130.0;
    final slotH = teamCount <= 16 ? 28.0 : 22.0;
    final matchGap = teamCount <= 8 ? 12.0 : teamCount <= 16 ? 10.0 : 6.0;
    final roundGap = teamCount <= 8 ? 50.0 : teamCount <= 16 ? 40.0 : 30.0;
    final headerH = 60.0;
    final footerH = 40.0;

    final halfRounds = rounds ~/ 2 + (rounds.isOdd ? 1 : 0);
    final champW = slotW + 30;
    final sideW = halfRounds * (slotW + roundGap);
    final canvasW = sideW + champW + sideW + 60;
    final firstRoundMatches = halfTeams ~/ 2;
    final matchH = slotH * 2 + matchGap;
    final bracketContentH = firstRoundMatches * matchH + (firstRoundMatches - 1) * matchGap;
    final canvasH = headerH + bracketContentH + footerH + 50;

    return _LayoutParams(
      rounds: rounds,
      halfTeams: halfTeams,
      halfRounds: halfRounds,
      slotW: slotW,
      slotH: slotH,
      matchGap: matchGap,
      roundGap: roundGap,
      headerH: headerH,
      footerH: footerH,
      champW: champW,
      canvasW: canvasW,
      canvasH: canvasH,
      bracketContentH: bracketContentH,
    );
  }

  static List<String> _roundNames(int totalRounds) {
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

  // ════════════════════════════════════════════════════════════════════
  // STYLE 1: CLASSIC — Matches the existing BMB hoodie prints exactly
  // ════════════════════════════════════════════════════════════════════

  static String _renderClassic({
    required int teamCount,
    required String bracketTitle,
    required String championName,
    required Map<String, String> picks,
    required List<String> teams,
    required BracketPrintPalette palette,
    required bool transparent,
    required bool showSeeds,
  }) {
    final lp = _computeLayout(teamCount);
    final buf = StringBuffer();

    _writeSvgOpen(buf, lp, transparent);

    // Title
    final cx = lp.canvasW / 2;
    buf.writeln('<text x="$cx" y="28" text-anchor="middle" fill="${palette.svgTitleColor}" '
        'font-size="22" font-weight="700" letter-spacing="2" '
        'font-family="ClashDisplay, Inter, sans-serif">${_esc(bracketTitle.toUpperCase())}</text>');

    // Champion box
    final champBoxW = championName.length * 11.0 + 40;
    buf.writeln('<rect x="${cx - champBoxW / 2}" y="36" width="$champBoxW" height="24" rx="4" '
        'fill="${palette.svgAccentColor}" opacity="0.2" stroke="${palette.svgAccentColor}" stroke-width="1"/>');
    buf.writeln('<text x="$cx" y="53" text-anchor="middle" fill="${palette.svgAccentColor}" '
        'font-size="13" font-weight="700" letter-spacing="1">${_esc(championName.toUpperCase())}</text>');

    // Bracket sides
    final bracketY = lp.headerH + 10;
    _writeBracketSideClassic(buf, 'left', 30, bracketY, lp, teams, picks, palette, showSeeds, 0);
    _writeBracketSideClassic(buf, 'right', lp.canvasW - 30, bracketY, lp, teams, picks, palette, showSeeds, lp.halfTeams);

    // BMB watermark bottom center
    final fy = lp.canvasH - 25;
    buf.writeln('<text x="$cx" y="$fy" text-anchor="middle" fill="${palette.svgTextColor}" '
        'opacity="0.25" font-size="10" font-weight="700" letter-spacing="4" '
        'font-family="ClashDisplay, Inter, sans-serif">BACKMYBRACKET.COM</text>');

    // BMB "B" watermark center
    final cy = lp.headerH + lp.bracketContentH / 2;
    _writeBmbWatermark(buf, cx, cy, teamCount <= 8 ? 70.0 : 55.0, palette);

    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _writeBracketSideClassic(
    StringBuffer buf, String side, double startX, double startY,
    _LayoutParams lp, List<String> teams, Map<String, String> picks,
    BracketPrintPalette palette, bool showSeeds, int seedOffset,
  ) {
    final isLeft = side == 'left';
    final sideRounds = lp.halfRounds;
    int matchesInRound = lp.halfTeams ~/ 2;
    final matchH = lp.slotH * 2 + lp.matchGap;
    final roundLabels = _roundNames(lp.rounds + 1);

    for (int r = 0; r < sideRounds; r++) {
      // Round label
      final rlX = isLeft
          ? startX + r * (lp.slotW + lp.roundGap) + lp.slotW / 2
          : startX - r * (lp.slotW + lp.roundGap) - lp.slotW / 2;
      if (r < roundLabels.length) {
        buf.writeln('<text x="$rlX" y="${startY - 5}" text-anchor="middle" '
            'fill="${palette.svgTextColor}" opacity="0.4" font-size="8" '
            'font-weight="600" letter-spacing="1.5">${roundLabels[r]}</text>');
      }

      final totalH = matchesInRound * matchH + (matchesInRound - 1) * lp.matchGap;
      final fmo = (startY + (lp.halfTeams ~/ 2 * matchH + (lp.halfTeams ~/ 2 - 1) * lp.matchGap) / 2) - totalH / 2;

      for (int m = 0; m < matchesInRound; m++) {
        final myCenterY = fmo + m * (matchH + lp.matchGap) + matchH / 2;
        final slotX = isLeft
            ? startX + r * (lp.slotW + lp.roundGap)
            : startX - r * (lp.slotW + lp.roundGap) - lp.slotW;

        // Team labels
        String topLabel = _getSlotLabel(picks, side, r, m, 1, teams, seedOffset);
        String botLabel = _getSlotLabel(picks, side, r, m, 2, teams, seedOffset);
        String topSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 1}' : '';
        String botSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 2}' : '';

        final topY = myCenterY - lp.slotH - lp.matchGap / 2;
        final botY = myCenterY + lp.matchGap / 2;

        // Slot pill boxes — Classic style
        _writeClassicSlot(buf, slotX, topY, lp.slotW, lp.slotH, topLabel, topSeed, r == 0, palette);
        _writeClassicSlot(buf, slotX, botY, lp.slotW, lp.slotH, botLabel, botSeed, r == 0, palette);

        // Connector lines
        final connX = isLeft ? slotX + lp.slotW : slotX;
        buf.writeln('<line x1="$connX" y1="${topY + lp.slotH / 2}" '
            'x2="$connX" y2="${botY + lp.slotH / 2}" '
            'stroke="${palette.svgLineColor}" stroke-width="1" opacity="0.6"/>');

        if (r < sideRounds - 1) {
          final hEnd = isLeft ? connX + lp.roundGap / 2 : connX - lp.roundGap / 2;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${palette.svgLineColor}" stroke-width="1" opacity="0.6"/>');
        } else {
          final hEnd = isLeft ? connX + lp.roundGap * 0.7 : connX - lp.roundGap * 0.7;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${palette.svgAccentColor}" stroke-width="1.5" opacity="0.7"/>');
        }
      }
      matchesInRound = (matchesInRound / 2).ceil();
      if (matchesInRound < 1) matchesInRound = 1;
    }
  }

  static void _writeClassicSlot(StringBuffer buf, double x, double y,
      double w, double h, String label, String seed, bool isFirstRound,
      BracketPrintPalette palette) {
    buf.writeln('<rect x="$x" y="$y" width="$w" height="$h" rx="4" '
        'fill="${palette.svgSlotFill}" stroke="${palette.svgSlotBorder}" stroke-width="0.8"/>');
    if (seed.isNotEmpty && isFirstRound) {
      buf.writeln('<text x="${x + 12}" y="${y + h / 2 + 4}" text-anchor="middle" '
          'fill="${palette.svgAccentColor}" font-size="8" font-weight="700">$seed</text>');
    }
    final textX = isFirstRound && seed.isNotEmpty ? x + 26 : x + 8;
    final display = label.length > 18 ? '${label.substring(0, 17)}..' : label;
    buf.writeln('<text x="$textX" y="${y + h / 2 + 4}" fill="${palette.svgTextColor}" '
        'font-size="${h > 24 ? 11 : 9}" font-weight="${label == 'TBD' ? '400' : '600'}" '
        'opacity="${label == 'TBD' ? '0.4' : '1'}">${_esc(display)}</text>');
  }

  // ════════════════════════════════════════════════════════════════════
  // STYLE 2: PREMIUM — Winner path, round labels, gold accents
  // ════════════════════════════════════════════════════════════════════

  static String _renderPremium({
    required int teamCount,
    required String bracketTitle,
    required String championName,
    required Map<String, String> picks,
    required List<String> teams,
    required BracketPrintPalette palette,
    required bool transparent,
    required bool showSeeds,
  }) {
    final lp = _computeLayout(teamCount);
    final buf = StringBuffer();
    _writeSvgOpen(buf, lp, transparent);

    final cx = lp.canvasW / 2;

    // Decorative line under title
    buf.writeln('<line x1="${cx - 80}" y1="18" x2="${cx + 80}" y2="18" '
        'stroke="${palette.svgAccentColor}" stroke-width="1" opacity="0.4"/>');

    // Title with accent underline
    buf.writeln('<text x="$cx" y="32" text-anchor="middle" fill="${palette.svgTitleColor}" '
        'font-size="20" font-weight="700" letter-spacing="3" '
        'font-family="ClashDisplay, Inter, sans-serif">${_esc(bracketTitle.toUpperCase())}</text>');

    // Champion in accent box with glow
    final champBoxW = championName.length * 10.0 + 50;
    buf.writeln('<rect x="${cx - champBoxW / 2 - 2}" y="38" width="${champBoxW + 4}" height="22" rx="6" '
        'fill="none" stroke="${palette.svgAccentColor}" stroke-width="1" opacity="0.3"/>');
    buf.writeln('<rect x="${cx - champBoxW / 2}" y="40" width="$champBoxW" height="18" rx="4" '
        'fill="${palette.svgAccentColor}" opacity="0.15" stroke="${palette.svgAccentColor}" stroke-width="1.5"/>');
    buf.writeln('<text x="$cx" y="54" text-anchor="middle" fill="${palette.svgAccentColor}" '
        'font-size="11" font-weight="700" letter-spacing="2">${_esc(championName.toUpperCase())}</text>');

    // Bracket sides — premium style
    final bracketY = lp.headerH + 10;
    _writeBracketSidePremium(buf, 'left', 30, bracketY, lp, teams, picks, palette, showSeeds, 0, championName);
    _writeBracketSidePremium(buf, 'right', lp.canvasW - 30, bracketY, lp, teams, picks, palette, showSeeds, lp.halfTeams, championName);

    // Footer
    final fy = lp.canvasH - 22;
    buf.writeln('<line x1="${cx - 60}" y1="${fy - 10}" x2="${cx + 60}" y2="${fy - 10}" '
        'stroke="${palette.svgAccentColor}" stroke-width="0.5" opacity="0.3"/>');
    buf.writeln('<text x="$cx" y="$fy" text-anchor="middle" fill="${palette.svgTextColor}" '
        'opacity="0.2" font-size="9" font-weight="700" letter-spacing="4">BACKMYBRACKET.COM</text>');

    _writeBmbWatermark(buf, cx, lp.headerH + lp.bracketContentH / 2,
        teamCount <= 8 ? 65.0 : 50.0, palette);

    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _writeBracketSidePremium(
    StringBuffer buf, String side, double startX, double startY,
    _LayoutParams lp, List<String> teams, Map<String, String> picks,
    BracketPrintPalette palette, bool showSeeds, int seedOffset, String champion,
  ) {
    final isLeft = side == 'left';
    final sideRounds = lp.halfRounds;
    int matchesInRound = lp.halfTeams ~/ 2;
    final matchH = lp.slotH * 2 + lp.matchGap;
    final roundLabels = _roundNames(lp.rounds + 1);

    for (int r = 0; r < sideRounds; r++) {
      final rlX = isLeft
          ? startX + r * (lp.slotW + lp.roundGap) + lp.slotW / 2
          : startX - r * (lp.slotW + lp.roundGap) - lp.slotW / 2;
      if (r < roundLabels.length) {
        buf.writeln('<text x="$rlX" y="${startY - 5}" text-anchor="middle" '
            'fill="${palette.svgAccentColor}" opacity="0.5" font-size="7" '
            'font-weight="700" letter-spacing="2">${roundLabels[r]}</text>');
      }

      final totalH = matchesInRound * matchH + (matchesInRound - 1) * lp.matchGap;
      final fmo = (startY + (lp.halfTeams ~/ 2 * matchH + (lp.halfTeams ~/ 2 - 1) * lp.matchGap) / 2) - totalH / 2;

      for (int m = 0; m < matchesInRound; m++) {
        final myCenterY = fmo + m * (matchH + lp.matchGap) + matchH / 2;
        final slotX = isLeft
            ? startX + r * (lp.slotW + lp.roundGap)
            : startX - r * (lp.slotW + lp.roundGap) - lp.slotW;

        String topLabel = _getSlotLabel(picks, side, r, m, 1, teams, seedOffset);
        String botLabel = _getSlotLabel(picks, side, r, m, 2, teams, seedOffset);
        String topSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 1}' : '';
        String botSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 2}' : '';

        final topY = myCenterY - lp.slotH - lp.matchGap / 2;
        final botY = myCenterY + lp.matchGap / 2;

        // Premium slots — rounded with accent on winner path
        final topIsChampPath = topLabel.toUpperCase() == champion.toUpperCase();
        final botIsChampPath = botLabel.toUpperCase() == champion.toUpperCase();

        _writePremiumSlot(buf, slotX, topY, lp.slotW, lp.slotH, topLabel, topSeed, r == 0, palette, topIsChampPath);
        _writePremiumSlot(buf, slotX, botY, lp.slotW, lp.slotH, botLabel, botSeed, r == 0, palette, botIsChampPath);

        // Connector lines — highlighted for champion path
        final connX = isLeft ? slotX + lp.slotW : slotX;
        final isChampConn = topIsChampPath || botIsChampPath;
        buf.writeln('<line x1="$connX" y1="${topY + lp.slotH / 2}" '
            'x2="$connX" y2="${botY + lp.slotH / 2}" '
            'stroke="${isChampConn ? palette.svgAccentColor : palette.svgLineColor}" '
            'stroke-width="${isChampConn ? '2' : '1'}" opacity="${isChampConn ? '0.8' : '0.5'}"/>');

        if (r < sideRounds - 1) {
          final hEnd = isLeft ? connX + lp.roundGap / 2 : connX - lp.roundGap / 2;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${isChampConn ? palette.svgAccentColor : palette.svgLineColor}" '
              'stroke-width="${isChampConn ? '1.5' : '1'}" opacity="${isChampConn ? '0.7' : '0.5'}"/>');
        } else {
          final hEnd = isLeft ? connX + lp.roundGap * 0.7 : connX - lp.roundGap * 0.7;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${palette.svgAccentColor}" stroke-width="2" opacity="0.8"/>');
        }
      }
      matchesInRound = (matchesInRound / 2).ceil();
      if (matchesInRound < 1) matchesInRound = 1;
    }
  }

  static void _writePremiumSlot(StringBuffer buf, double x, double y,
      double w, double h, String label, String seed, bool isFirstRound,
      BracketPrintPalette palette, bool isChampPath) {
    final borderColor = isChampPath ? palette.svgAccentColor : palette.svgSlotBorder;
    final borderW = isChampPath ? '1.5' : '0.8';
    buf.writeln('<rect x="$x" y="$y" width="$w" height="$h" rx="6" '
        'fill="${palette.svgSlotFill}" stroke="$borderColor" stroke-width="$borderW"/>');
    if (seed.isNotEmpty && isFirstRound) {
      buf.writeln('<circle cx="${x + 12}" cy="${y + h / 2}" r="8" '
          'fill="${palette.svgAccentColor}" opacity="0.2"/>');
      buf.writeln('<text x="${x + 12}" y="${y + h / 2 + 3}" text-anchor="middle" '
          'fill="${palette.svgAccentColor}" font-size="7" font-weight="700">$seed</text>');
    }
    final textX = isFirstRound && seed.isNotEmpty ? x + 26 : x + 8;
    final display = label.length > 18 ? '${label.substring(0, 17)}..' : label;
    final weight = isChampPath ? '700' : (label == 'TBD' ? '400' : '600');
    buf.writeln('<text x="$textX" y="${y + h / 2 + 4}" fill="${palette.svgTextColor}" '
        'font-size="${h > 24 ? 11 : 9}" font-weight="$weight" '
        'opacity="${label == 'TBD' ? '0.3' : '1'}">${_esc(display)}</text>');
  }

  // ════════════════════════════════════════════════════════════════════
  // STYLE 3: BOLD — Solid fills, thick lines, streetwear-forward
  // ════════════════════════════════════════════════════════════════════

  static String _renderBold({
    required int teamCount,
    required String bracketTitle,
    required String championName,
    required Map<String, String> picks,
    required List<String> teams,
    required BracketPrintPalette palette,
    required bool transparent,
    required bool showSeeds,
  }) {
    final lp = _computeLayout(teamCount);
    final buf = StringBuffer();
    _writeSvgOpen(buf, lp, transparent);

    final cx = lp.canvasW / 2;

    // Bold title — large, heavy
    buf.writeln('<text x="$cx" y="30" text-anchor="middle" fill="${palette.svgTitleColor}" '
        'font-size="26" font-weight="900" letter-spacing="4" '
        'font-family="ClashDisplay, Inter, sans-serif">${_esc(bracketTitle.toUpperCase())}</text>');

    // Champion banner
    final bannerW = championName.length * 12.0 + 60;
    buf.writeln('<rect x="${cx - bannerW / 2}" y="38" width="$bannerW" height="22" rx="3" '
        'fill="${palette.svgAccentColor}" opacity="0.3"/>');
    buf.writeln('<rect x="${cx - bannerW / 2 + 2}" y="40" width="${bannerW - 4}" height="18" rx="2" '
        'fill="${palette.svgAccentColor}" opacity="0.15" stroke="${palette.svgAccentColor}" stroke-width="2"/>');
    buf.writeln('<text x="$cx" y="54" text-anchor="middle" fill="${palette.svgTitleColor}" '
        'font-size="12" font-weight="900" letter-spacing="3">${_esc(championName.toUpperCase())}</text>');

    // Bracket sides
    final bracketY = lp.headerH + 10;
    _writeBracketSideBold(buf, 'left', 30, bracketY, lp, teams, picks, palette, showSeeds, 0);
    _writeBracketSideBold(buf, 'right', lp.canvasW - 30, bracketY, lp, teams, picks, palette, showSeeds, lp.halfTeams);

    // Bold footer
    final fy = lp.canvasH - 20;
    buf.writeln('<text x="$cx" y="$fy" text-anchor="middle" fill="${palette.svgTextColor}" '
        'opacity="0.3" font-size="11" font-weight="900" letter-spacing="5">BACKMYBRACKET.COM</text>');

    // Larger BMB watermark for bold style
    _writeBmbWatermark(buf, cx, lp.headerH + lp.bracketContentH / 2,
        teamCount <= 8 ? 80.0 : 60.0, palette);

    buf.writeln('</svg>');
    return buf.toString();
  }

  static void _writeBracketSideBold(
    StringBuffer buf, String side, double startX, double startY,
    _LayoutParams lp, List<String> teams, Map<String, String> picks,
    BracketPrintPalette palette, bool showSeeds, int seedOffset,
  ) {
    final isLeft = side == 'left';
    final sideRounds = lp.halfRounds;
    int matchesInRound = lp.halfTeams ~/ 2;
    final matchH = lp.slotH * 2 + lp.matchGap;

    for (int r = 0; r < sideRounds; r++) {
      final totalH = matchesInRound * matchH + (matchesInRound - 1) * lp.matchGap;
      final fmo = (startY + (lp.halfTeams ~/ 2 * matchH + (lp.halfTeams ~/ 2 - 1) * lp.matchGap) / 2) - totalH / 2;

      for (int m = 0; m < matchesInRound; m++) {
        final myCenterY = fmo + m * (matchH + lp.matchGap) + matchH / 2;
        final slotX = isLeft
            ? startX + r * (lp.slotW + lp.roundGap)
            : startX - r * (lp.slotW + lp.roundGap) - lp.slotW;

        String topLabel = _getSlotLabel(picks, side, r, m, 1, teams, seedOffset);
        String botLabel = _getSlotLabel(picks, side, r, m, 2, teams, seedOffset);
        String topSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 1}' : '';
        String botSeed = (r == 0 && showSeeds) ? '#${seedOffset + m * 2 + 2}' : '';

        final topY = myCenterY - lp.slotH - lp.matchGap / 2;
        final botY = myCenterY + lp.matchGap / 2;

        // Bold slots — solid filled boxes
        _writeBoldSlot(buf, slotX, topY, lp.slotW, lp.slotH, topLabel, topSeed, r == 0, palette);
        _writeBoldSlot(buf, slotX, botY, lp.slotW, lp.slotH, botLabel, botSeed, r == 0, palette);

        // Thick connector lines
        final connX = isLeft ? slotX + lp.slotW : slotX;
        buf.writeln('<line x1="$connX" y1="${topY + lp.slotH / 2}" '
            'x2="$connX" y2="${botY + lp.slotH / 2}" '
            'stroke="${palette.svgLineColor}" stroke-width="2" opacity="0.7"/>');

        if (r < sideRounds - 1) {
          final hEnd = isLeft ? connX + lp.roundGap / 2 : connX - lp.roundGap / 2;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${palette.svgLineColor}" stroke-width="2" opacity="0.7"/>');
        } else {
          final hEnd = isLeft ? connX + lp.roundGap * 0.7 : connX - lp.roundGap * 0.7;
          buf.writeln('<line x1="$connX" y1="$myCenterY" x2="$hEnd" y2="$myCenterY" '
              'stroke="${palette.svgAccentColor}" stroke-width="3" opacity="0.9"/>');
        }
      }
      matchesInRound = (matchesInRound / 2).ceil();
      if (matchesInRound < 1) matchesInRound = 1;
    }
  }

  static void _writeBoldSlot(StringBuffer buf, double x, double y,
      double w, double h, String label, String seed, bool isFirstRound,
      BracketPrintPalette palette) {
    // Solid fill for bold style — inverted: white box with dark text on dark garments
    final isTbd = label == 'TBD';
    if (isTbd) {
      buf.writeln('<rect x="$x" y="$y" width="$w" height="$h" rx="3" '
          'fill="${palette.svgSlotFill}" stroke="${palette.svgSlotBorder}" stroke-width="1"/>');
    } else {
      buf.writeln('<rect x="$x" y="$y" width="$w" height="$h" rx="3" '
          'fill="${palette.svgTextColor}" opacity="0.9"/>');
    }
    if (seed.isNotEmpty && isFirstRound) {
      buf.writeln('<rect x="$x" y="$y" width="24" height="$h" rx="3" '
          'fill="${palette.svgAccentColor}" opacity="0.8"/>');
      buf.writeln('<text x="${x + 12}" y="${y + h / 2 + 3}" text-anchor="middle" '
          'fill="${isTbd ? palette.svgTextColor : palette.svgSlotFill}" '
          'font-size="8" font-weight="900">$seed</text>');
    }
    final textX = isFirstRound && seed.isNotEmpty ? x + 30 : x + 8;
    final display = label.length > 16 ? '${label.substring(0, 15)}..' : label;
    // Bold: inverted text color (dark text on light fill)
    final textColor = isTbd ? palette.svgTextColor : palette.svgSlotFill;
    buf.writeln('<text x="$textX" y="${y + h / 2 + 4}" '
        'fill="$textColor" font-size="${h > 24 ? 11 : 9}" font-weight="900" '
        'opacity="${isTbd ? '0.3' : '1'}">${_esc(display)}</text>');
  }

  // ════════════════════════════════════════════════════════════════════
  // SHARED HELPERS
  // ════════════════════════════════════════════════════════════════════

  /// SVG header. Always portrait (canvasH > canvasW). RGB colour mode.
  static void _writeSvgOpen(StringBuffer buf, _LayoutParams lp, bool transparent) {
    // ── Portrait enforcement at SVG output level ──────────────
    assert(lp.canvasH >= lp.canvasW,
        'SVG canvas must be portrait (${lp.canvasW}x${lp.canvasH})');

    buf.writeln('<?xml version="1.0" encoding="UTF-8"?>');
    // color-profile: sRGB → ensures RGB interpretation by the printer.
    buf.writeln('<svg xmlns="http://www.w3.org/2000/svg" '
        'viewBox="0 0 ${lp.canvasW} ${lp.canvasH}" '
        'width="${lp.canvasW}" height="${lp.canvasH}" '
        'color-profile="sRGB" '
        '${transparent ? '' : 'style="background:#0A0E27" '}'
        'font-family="\'ClashDisplay\', \'Inter\', \'Segoe UI\', sans-serif">');
  }

  static void _writeBmbWatermark(StringBuffer buf, double cx, double cy, double size, BracketPrintPalette palette) {
    final s = size;
    final x = cx - s / 2;
    final y = cy - s / 2;
    buf.writeln('<g opacity="0.06" transform="translate($x, $y)">');
    buf.writeln('  <path d="'
        'M${s * 0.15},${s * 0.1} L${s * 0.65},${s * 0.1} '
        'Q${s * 0.85},${s * 0.1} ${s * 0.85},${s * 0.3} '
        'Q${s * 0.85},${s * 0.45} ${s * 0.65},${s * 0.5} '
        'Q${s * 0.9},${s * 0.55} ${s * 0.9},${s * 0.72} '
        'Q${s * 0.9},${s * 0.9} ${s * 0.65},${s * 0.9} '
        'L${s * 0.15},${s * 0.9} Z'
        '" fill="${palette.svgTextColor}"/>');
    buf.writeln('</g>');
  }

  /// Get label for a bracket slot from picks map or first-round teams.
  static String _getSlotLabel(Map<String, String> picks, String side, int round, int match, int teamNum, List<String> teams, int seedOffset) {
    final key = 'slot_${side}_r${round}_m${match}_team$teamNum';
    if (picks.containsKey(key)) return picks[key]!;
    if (round == 0) {
      final idx = seedOffset + match * 2 + (teamNum - 1);
      if (idx < teams.length) return teams[idx];
    }
    return 'TBD';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;');
}

class _LayoutParams {
  final int rounds;
  final int halfTeams;
  final int halfRounds;
  final double slotW;
  final double slotH;
  final double matchGap;
  final double roundGap;
  final double headerH;
  final double footerH;
  final double champW;
  final double canvasW;
  final double canvasH;
  final double bracketContentH;

  const _LayoutParams({
    required this.rounds,
    required this.halfTeams,
    required this.halfRounds,
    required this.slotW,
    required this.slotH,
    required this.matchGap,
    required this.roundGap,
    required this.headerH,
    required this.footerH,
    required this.champW,
    required this.canvasW,
    required this.canvasH,
    required this.bracketContentH,
  });
}
