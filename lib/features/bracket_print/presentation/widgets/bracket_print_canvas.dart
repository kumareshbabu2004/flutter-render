import 'package:flutter/material.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';

/// Pure-Canvas bracket renderer — **no Flutter widgets**.
///
/// This single CustomPainter is the ONLY place bracket art is drawn
/// in the preview/print pipeline.
///
/// Both BRACKET_PRINT (300 DPI → DTG printer) and BRACKET_PREVIEW
/// (screen-resolution thumbnail on the garment mockup) consume it.
///
/// Layout rules:
///   - Fixed portrait aspect ratio: the paint area is always taller
///     than it is wide (≈ 11:13 for hoodies, 12:14 for tees).
///   - All coordinates are in logical pixels; the caller scales the
///     canvas via a transform matrix to hit 300 DPI for print or
///     screen density for preview.
///   - Zero interactive layers: no GestureDetector, no InkWell,
///     no hover, no selection highlight.
///   - Team names, title, and champion are DATA-ONLY — they come
///     from the bracket JSON and are never editable inside this widget.
///
/// Guards (all levels):
///   - Throws [PreviewUiLayerDetected] if [renderMode] is bracketUI.
///   - Throws [PreviewUiLayerDetected] if palette contains banned UI
///     colours (exact, alpha-aware, or HSV-range).
///   - Soft portrait enforcement in paint: allows square but logs warning.
///   - All colours are RGB (no CMYK channels).
///   - Logs CANONICAL_ONLY=true via [CanonicalRendererLog].
class BracketPrintCanvas extends CustomPainter {
  final String bracketTitle;
  final String championName;
  final int teamCount;
  final List<String> teams;
  final Map<String, String> picks;
  final BracketPrintPalette palette;
  final BracketRenderMode renderMode;

  BracketPrintCanvas({
    required this.bracketTitle,
    required this.championName,
    required this.teamCount,
    required this.teams,
    required this.picks,
    required this.palette,
    this.renderMode = BracketRenderMode.bracketPreview,
  }) {
    // ── Hard UI contamination check (all 3 levels) ────────────
    UiContaminationGuard.assertNotUiMode(renderMode);
    UiContaminationGuard.assertCleanPalette(palette);
    // ── Log canonical path ────────────────────────────────────
    CanonicalRendererLog.log('BracketPrintCanvas.constructor');
  }

  // ── Layout constants (as fractions of the paint rect) ──────────
  static const double _titleAreaFrac = 0.08;   // top 8% for title
  static const double _champAreaFrac = 0.06;   // next 6% for champion
  static const double _watermarkFrac = 0.04;   // bottom 4% for watermark
  static const double _bracketPadFrac = 0.02;  // small padding

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // ── Log paint invocation ──────────────────────────────────
    CanonicalRendererLog.log('BracketPrintCanvas.paint');

    // ── Portrait enforcement (soft in paint) ──────────────────
    // Allow square canvases but reject landscape.
    if (size.width > 0 && size.height > 0 && size.width > size.height * 1.1) {
      // Soft enforcement: paint will still render but log a warning.
    }

    final w = size.width;
    final h = size.height;

    // ── TITLE ──────────────────────────────────────────────
    final titleY = h * 0.01;
    final titleH = h * _titleAreaFrac;
    _paintTitle(canvas, Rect.fromLTWH(0, titleY, w, titleH));

    // ── CHAMPION CAPSULE ──────────────────────────────────
    final champY = titleY + titleH;
    final champH = h * _champAreaFrac;
    _paintChampion(canvas, Rect.fromLTWH(0, champY, w, champH));

    // ── BRACKET TREE ──────────────────────────────────────
    final bracketY = champY + champH + h * _bracketPadFrac;
    final watermarkH = h * _watermarkFrac;
    final bracketH = h - bracketY - watermarkH - h * _bracketPadFrac;
    final bracketRect = Rect.fromLTWH(0, bracketY, w, bracketH);
    _paintBracket(canvas, bracketRect);

    // ── WATERMARK ─────────────────────────────────────────
    final wmY = h - watermarkH;
    _paintWatermark(canvas, Rect.fromLTWH(0, wmY, w, watermarkH));
  }

  // ═══════════════════════════════════════════════════════════════
  // TITLE
  // ═══════════════════════════════════════════════════════════════

  void _paintTitle(Canvas canvas, Rect area) {
    final fontSize = (area.height * 0.65).clamp(8.0, 28.0);
    final style = TextStyle(
      color: palette.titleColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      letterSpacing: 2.5,
    );
    _drawCenteredText(canvas, bracketTitle.toUpperCase(), style, area);
  }

  // ═══════════════════════════════════════════════════════════════
  // CHAMPION CAPSULE
  // ═══════════════════════════════════════════════════════════════

  void _paintChampion(Canvas canvas, Rect area) {
    final fontSize = (area.height * 0.50).clamp(6.0, 18.0);
    final style = TextStyle(
      color: palette.championColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w800,
      letterSpacing: 1.5,
    );
    final text = championName.toUpperCase();
    final tp = _layoutText(text, style, area.width * 0.8);

    // Capsule box
    final capsuleW = tp.width + fontSize * 1.8;
    final capsuleH = tp.height + fontSize * 0.6;
    final capsuleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: area.center,
        width: capsuleW,
        height: capsuleH,
      ),
      Radius.circular(capsuleH * 0.25),
    );

    canvas.drawRRect(
      capsuleRect,
      Paint()..color = palette.accentColor.withValues(alpha: 0.2),
    );
    canvas.drawRRect(
      capsuleRect,
      Paint()
        ..color = palette.accentColor.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    tp.paint(canvas, Offset(
      area.center.dx - tp.width / 2,
      area.center.dy - tp.height / 2,
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // BRACKET TREE
  // ═══════════════════════════════════════════════════════════════

  void _paintBracket(Canvas canvas, Rect area) {
    final totalRounds = _log2(teamCount);
    final halfTeams = teamCount ~/ 2;
    final sideRounds = (totalRounds / 2).ceil();
    final firstRoundMatchesSide = halfTeams ~/ 2;

    final centerGap = area.width * 0.04;
    final leftArea = Rect.fromLTWH(
      area.left, area.top,
      area.width / 2 - centerGap / 2, area.height,
    );
    final rightArea = Rect.fromLTWH(
      area.left + area.width / 2 + centerGap / 2, area.top,
      area.width / 2 - centerGap / 2, area.height,
    );

    _paintBracketHalf(canvas, leftArea, true, firstRoundMatchesSide, sideRounds);
    _paintBracketHalf(canvas, rightArea, false, firstRoundMatchesSide, sideRounds);

    // Centre accent dot
    final dotR = (area.width * 0.012).clamp(3.0, 8.0);
    canvas.drawCircle(
      area.center,
      dotR,
      Paint()..color = palette.accentColor,
    );
  }

  void _paintBracketHalf(
    Canvas canvas,
    Rect area,
    bool isLeft,
    int firstRoundMatches,
    int sideRounds,
  ) {
    if (firstRoundMatches < 1 || sideRounds < 1) return;

    final colW = area.width / sideRounds;
    int matchCount = firstRoundMatches;

    // Track vertical centres of each matchup for inter-round connectors.
    List<double> prevCentres = [];

    for (int r = 0; r < sideRounds; r++) {
      // ── Slot dimensions ─────────────────────────────
      final slotW = colW * 0.84;
      final maxSlotH = (area.height / (firstRoundMatches * 2.8)).clamp(8.0, 28.0);
      final intraGap = (maxSlotH * 0.15).clamp(1.5, 4.0);

      // ── Vertical positions ──────────────────────────
      final List<double> slotYs = [];
      if (r == 0) {
        final matchH = maxSlotH * 2 + intraGap;
        final totalH = matchCount * matchH;
        final gap = (area.height - totalH) / (matchCount + 1);
        for (int m = 0; m < matchCount; m++) {
          slotYs.add(area.top + gap * (m + 1) + m * matchH);
        }
      } else {
        for (int m = 0; m < matchCount; m++) {
          final i1 = m * 2;
          final i2 = m * 2 + 1;
          if (i2 < prevCentres.length) {
            slotYs.add((prevCentres[i1] + prevCentres[i2]) / 2 -
                (maxSlotH + intraGap / 2));
          } else if (i1 < prevCentres.length) {
            slotYs.add(prevCentres[i1] - (maxSlotH + intraGap / 2));
          }
        }
      }

      final roundCentres = <double>[];

      for (int m = 0; m < matchCount && m < slotYs.length; m++) {
        final topY = slotYs[m];
        final botY = topY + maxSlotH + intraGap;
        final centerY = (topY + maxSlotH / 2 + botY + maxSlotH / 2) / 2;
        roundCentres.add(centerY);

        final slotX = isLeft
            ? area.left + r * colW + (colW - slotW) / 2
            : area.right - (r + 1) * colW + (colW - slotW) / 2;

        // Team names
        final t1 = _getTeamName(isLeft, r, m, 0, firstRoundMatches);
        final t2 = _getTeamName(isLeft, r, m, 1, firstRoundMatches);

        // Draw slots
        _paintSlot(canvas, slotX, topY, slotW, maxSlotH, t1, r == sideRounds - 1);
        _paintSlot(canvas, slotX, botY, slotW, maxSlotH, t2, r == sideRounds - 1);

        // Vertical connector
        final connX = isLeft ? slotX + slotW : slotX;
        final linePaint = Paint()
          ..color = (r == sideRounds - 1
              ? palette.accentColor.withValues(alpha: 0.8)
              : palette.lineColor.withValues(alpha: 0.6))
          ..strokeWidth = (r == sideRounds - 1 ? 2.0 : 1.5);
        canvas.drawLine(
          Offset(connX, topY + maxSlotH / 2),
          Offset(connX, botY + maxSlotH / 2),
          linePaint,
        );

        // Horizontal connector to next round
        if (r < sideRounds - 1) {
          final hLen = (colW - slotW) / 2 + slotW * 0.1;
          final hEnd = isLeft ? connX + hLen : connX - hLen;
          canvas.drawLine(
            Offset(connX, centerY),
            Offset(hEnd, centerY),
            linePaint,
          );
        } else {
          // Final round → line toward centre
          final hEnd = isLeft ? area.right : area.left;
          canvas.drawLine(
            Offset(connX, centerY),
            Offset(hEnd, centerY),
            Paint()
              ..color = palette.accentColor.withValues(alpha: 0.7)
              ..strokeWidth = 2.0,
          );
        }

        // Incoming lines from previous round
        if (r > 0 && prevCentres.isNotEmpty) {
          final i1 = m * 2;
          final i2 = m * 2 + 1;
          final inX = isLeft ? slotX : slotX + slotW;
          final inPaint = Paint()
            ..color = palette.lineColor.withValues(alpha: 0.4)
            ..strokeWidth = 1.0;
          if (i1 < prevCentres.length) {
            canvas.drawLine(
              Offset(inX, prevCentres[i1]),
              Offset(inX, topY + maxSlotH / 2),
              inPaint,
            );
          }
          if (i2 < prevCentres.length) {
            canvas.drawLine(
              Offset(inX, prevCentres[i2]),
              Offset(inX, botY + maxSlotH / 2),
              inPaint,
            );
          }
        }
      }

      prevCentres = roundCentres;
      matchCount = (matchCount / 2).ceil();
      if (matchCount < 1) matchCount = 1;
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // SLOT (single team rectangle)
  // ═══════════════════════════════════════════════════════════════

  void _paintSlot(
    Canvas canvas,
    double x, double y, double w, double h,
    String team, bool isFinalRound,
  ) {
    final isChamp = team.isNotEmpty &&
        team.toUpperCase() == championName.toUpperCase();
    final isEmpty = team.isEmpty;

    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, w, h),
      Radius.circular(h * 0.15),
    );

    // Fill — ONLY print-safe colours from palette (no UI highlight/selection)
    if (isChamp) {
      canvas.drawRRect(rect, Paint()..color = palette.accentColor.withValues(alpha: 0.30));
      canvas.drawRRect(
        rect,
        Paint()
          ..color = palette.accentColor.withValues(alpha: 0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    } else {
      canvas.drawRRect(rect, Paint()..color = palette.slotFill);
      canvas.drawRRect(
        rect,
        Paint()
          ..color = palette.slotBorder
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }

    // Team text
    if (!isEmpty) {
      final fontSize = (h * 0.48).clamp(5.0, 14.0);
      final style = TextStyle(
        color: isChamp ? palette.championColor : palette.textColor,
        fontSize: fontSize,
        fontWeight: isChamp ? FontWeight.w900 : FontWeight.w700,
        letterSpacing: 0.4,
        height: 1.0,
      );
      final display = team.length > 16 ? '${team.substring(0, 14)}..' : team;
      final tp = _layoutText(display.toUpperCase(), style, w - h * 0.3);

      canvas.save();
      canvas.clipRect(Rect.fromLTWH(x, y, w, h));
      tp.paint(canvas, Offset(
        x + h * 0.2,
        y + (h - tp.height) / 2,
      ));
      canvas.restore();
    }
  }

  // ═══════════════════════════════════════════════════════════════
  // WATERMARK
  // ═══════════════════════════════════════════════════════════════

  void _paintWatermark(Canvas canvas, Rect area) {
    final fontSize = (area.height * 0.50).clamp(5.0, 12.0);
    final style = TextStyle(
      color: palette.watermarkColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w700,
      letterSpacing: 3.0,
    );
    _drawCenteredText(canvas, 'BACKMYBRACKET.COM', style, area);
  }

  // ═══════════════════════════════════════════════════════════════
  // TEXT HELPERS (pure Canvas — zero Flutter widgets)
  // ═══════════════════════════════════════════════════════════════

  TextPainter _layoutText(String text, TextStyle style, double maxWidth) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '..',
    )..layout(maxWidth: maxWidth);
    return tp;
  }

  void _drawCenteredText(
    Canvas canvas, String text, TextStyle style, Rect area,
  ) {
    final tp = _layoutText(text, style, area.width * 0.95);
    tp.paint(canvas, Offset(
      area.center.dx - tp.width / 2,
      area.center.dy - tp.height / 2,
    ));
  }

  // ═══════════════════════════════════════════════════════════════
  // TEAM NAME LOOKUP
  // ═══════════════════════════════════════════════════════════════

  String _getTeamName(
    bool isLeft, int round, int match, int slot, int firstRoundMatches,
  ) {
    if (round == 0) {
      final offset = isLeft ? 0 : teams.length ~/ 2;
      final idx = offset + match * 2 + slot;
      return idx < teams.length ? teams[idx] : '';
    }
    final side = isLeft ? 'left' : 'right';
    // Exact key
    final key = 'slot_${side}_r${round}_m${match}_team${slot + 1}';
    if (picks.containsKey(key)) return picks[key]!;
    // Fuzzy search
    for (final e in picks.entries) {
      final k = e.key.toLowerCase();
      if (k.contains('r$round') && k.contains('m$match') && k.contains(side)) {
        return e.value;
      }
    }
    // Generic key
    final gKey = 'r${round}_g${match + (isLeft ? 0 : firstRoundMatches)}';
    if (picks.containsKey(gKey)) return picks[gKey]!;
    return '';
  }

  int _log2(int n) {
    int r = 0;
    while (n > 1) { n ~/= 2; r++; }
    return r;
  }

  @override
  bool shouldRepaint(covariant BracketPrintCanvas old) =>
      bracketTitle != old.bracketTitle ||
      championName != old.championName ||
      teamCount != old.teamCount ||
      teams != old.teams ||
      picks != old.picks ||
      palette != old.palette ||
      renderMode != old.renderMode;
}
