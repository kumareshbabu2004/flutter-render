import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:bmb_mobile/features/bracket_print/data/models/print_product.dart';

/// Custom painter replicating the real BMB bracket-on-garment print.
///
/// Reference: white-filled rectangular slots with dark text on a dark garment,
/// bracket lines connecting matchups, title at top center, champion capsule
/// below title, BMB logo at bottom center, bracket covers ~80% of garment back.
class GarmentMockupPainter extends CustomPainter {
  final GarmentColor garmentColor;
  final PrintProductType productType;
  final int teamCount;
  final BracketPrintPalette bracketPalette;
  final String bracketTitle;
  final String championName;
  final List<String> teams;
  final BracketPrintStyle printStyle;
  final Map<String, String> picks;

  GarmentMockupPainter({
    required this.garmentColor,
    required this.productType,
    required this.teamCount,
    required this.bracketPalette,
    required this.bracketTitle,
    required this.championName,
    required this.teams,
    required this.printStyle,
    this.picks = const {},
  }) {
    // ── Contamination guards (all levels) ─────────────────────
    UiContaminationGuard.assertCleanPalette(bracketPalette);
    // ── Log canonical path ────────────────────────────────────
    CanonicalRendererLog.log('GarmentMockupPainter.constructor');
  }

  @override
  void paint(Canvas canvas, Size size) {
    CanonicalRendererLog.log('GarmentMockupPainter.paint');
    if (productType == PrintProductType.hoodie) {
      _drawHoodieBack(canvas, size);
    } else {
      _drawTShirtBack(canvas, size);
    }
    _drawBracketPrint(canvas, size);
  }

  // ─── GARMENT SILHOUETTES ───────────────────────────────────────

  void _drawHoodieBack(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = garmentColor.color;
    final shadow = Paint()..color = Colors.black.withValues(alpha: 0.15);
    final stitch = Paint()
      ..color = (garmentColor.isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final body = Path()
      ..moveTo(w * 0.18, h * 0.22)..lineTo(w * 0.02, h * 0.35)
      ..lineTo(w * 0.06, h * 0.55)..lineTo(w * 0.16, h * 0.45)
      ..lineTo(w * 0.14, h * 0.92)
      ..quadraticBezierTo(w * 0.5, h * 0.96, w * 0.86, h * 0.92)
      ..lineTo(w * 0.84, h * 0.45)..lineTo(w * 0.94, h * 0.55)
      ..lineTo(w * 0.98, h * 0.35)..lineTo(w * 0.82, h * 0.22)..close();
    canvas.drawPath(body, paint);

    final hood = Path()
      ..moveTo(w * 0.25, h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.08, w * 0.75, h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.16, w * 0.25, h * 0.22)..close();
    canvas.drawPath(hood, paint);
    canvas.drawPath(hood, shadow);

    final neck = Path()
      ..moveTo(w * 0.32, h * 0.22)
      ..quadraticBezierTo(w * 0.5, h * 0.19, w * 0.68, h * 0.22);
    canvas.drawPath(neck, stitch);
    canvas.drawLine(Offset(w * 0.5, h * 0.22), Offset(w * 0.5, h * 0.92), stitch);
    canvas.drawLine(Offset(w * 0.18, h * 0.22), Offset(w * 0.5, h * 0.20), stitch);
    canvas.drawLine(Offset(w * 0.82, h * 0.22), Offset(w * 0.5, h * 0.20), stitch);
  }

  void _drawTShirtBack(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final paint = Paint()..color = garmentColor.color;
    final stitch = Paint()
      ..color = (garmentColor.isDark ? Colors.white : Colors.black).withValues(alpha: 0.06)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    final body = Path()
      ..moveTo(w * 0.22, h * 0.14)..lineTo(w * 0.02, h * 0.22)
      ..lineTo(w * 0.08, h * 0.35)..lineTo(w * 0.18, h * 0.30)
      ..lineTo(w * 0.16, h * 0.94)..lineTo(w * 0.84, h * 0.94)
      ..lineTo(w * 0.82, h * 0.30)..lineTo(w * 0.92, h * 0.35)
      ..lineTo(w * 0.98, h * 0.22)..lineTo(w * 0.78, h * 0.14)..close();
    canvas.drawPath(body, paint);

    final neck = Path()
      ..moveTo(w * 0.32, h * 0.14)
      ..quadraticBezierTo(w * 0.5, h * 0.10, w * 0.68, h * 0.14);
    canvas.drawPath(neck, stitch);
    canvas.drawLine(Offset(w * 0.5, h * 0.14), Offset(w * 0.5, h * 0.94), stitch);
  }

  // ─── BRACKET PRINT ─────────────────────────────────────────────

  void _drawBracketPrint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Print zone: shoulder-to-lower-back
    final printRect = Rect.fromLTWH(w * 0.08, h * 0.15, w * 0.84, h * 0.74);
    final pal = bracketPalette;
    final totalRounds = _log2(teamCount);
    final halfTeams = teamCount ~/ 2;

    // ── Title (e.g. "NCAA 2024") ──
    final titleFs = (printRect.width / math.max(bracketTitle.length * 0.65, 8)).clamp(8.0, 14.0);
    _paintText(canvas, bracketTitle.toUpperCase(),
        TextStyle(color: pal.titleColor, fontSize: titleFs, fontWeight: FontWeight.w800, letterSpacing: 2),
        Offset(printRect.center.dx, printRect.top + 6), center: true);

    // ── Champion capsule (e.g. "GEORGIA") ──
    final champY = printRect.top + 22;
    final champFs = (printRect.width / 38).clamp(5.0, 10.0);
    final champSty = TextStyle(color: pal.championColor, fontSize: champFs, fontWeight: FontWeight.w800, letterSpacing: 1);
    final champTxt = championName.toUpperCase();
    final champSz = _measure(champTxt, champSty);
    final capsule = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(printRect.center.dx, champY),
          width: champSz.width + 16, height: champSz.height + 8),
      const Radius.circular(4));
    canvas.drawRRect(capsule, Paint()..color = pal.accentColor.withValues(alpha: 0.2));
    canvas.drawRRect(capsule, Paint()
      ..color = pal.accentColor.withValues(alpha: 0.6)..style = PaintingStyle.stroke..strokeWidth = 0.8);
    _paintText(canvas, champTxt, champSty, Offset(printRect.center.dx, champY), center: true);

    // ── Bracket area (below champion, above watermark) ──
    final bracketTop = champY + champSz.height / 2 + 10;
    final bracketBottom = printRect.bottom - 18;
    final bracketH = bracketBottom - bracketTop;
    final centerX = printRect.center.dx;
    final centerGap = 6.0; // px between left and right halves

    // Each half
    final leftArea = Rect.fromLTWH(printRect.left, bracketTop, printRect.width / 2 - centerGap, bracketH);
    final rightArea = Rect.fromLTWH(centerX + centerGap, bracketTop, printRect.width / 2 - centerGap, bracketH);

    // Side rounds: for 8-team (3 total rounds) each side gets 2 rounds
    // for 16-team (4 total rounds) each side gets 2 rounds, etc.
    final sideRounds = (totalRounds / 2).ceil();

    _drawHalf(canvas, leftArea, halfTeams, sideRounds, true, pal);
    _drawHalf(canvas, rightArea, halfTeams, sideRounds, false, pal);

    // ── Center connector lines (to championship) ──
    final centerY = bracketTop + bracketH / 2;
    final acPaint = Paint()..color = pal.accentColor.withValues(alpha: 0.8)..strokeWidth = 1.0;
    canvas.drawLine(Offset(leftArea.right + 1, centerY), Offset(centerX - 1, centerY), acPaint);
    canvas.drawLine(Offset(rightArea.left - 1, centerY), Offset(centerX + 1, centerY), acPaint);

    // ── BMB Logo placeholder at bottom center ──
    _paintText(canvas, 'BACKMYBRACKET.COM',
        TextStyle(color: pal.watermarkColor, fontSize: 5, fontWeight: FontWeight.w700, letterSpacing: 2),
        Offset(printRect.center.dx, printRect.bottom - 6), center: true);
  }

  /// Draw one half of the bracket tree.
  void _drawHalf(Canvas canvas, Rect area, int halfTeams,
      int sideRounds, bool isLeft, BracketPrintPalette pal) {
    final firstRoundMatches = halfTeams ~/ 2;
    if (firstRoundMatches < 1) return;

    // Column width per round
    final colW = area.width / sideRounds;

    // Slot dimensions — height adapts to fit all first-round matchups
    // Each matchup = 2 slots + gap. Total vertical: firstRoundMatches * (2*slotH + intraGap) + (fRM-1)*interGap
    final maxSlotH = 10.0;
    final minSlotH = 4.0;
    final intraGap = 2.0; // gap between top/bot slot in a match
    final matchUnit = maxSlotH * 2 + intraGap;
    final totalNeeded = firstRoundMatches * matchUnit;
    double slotH;
    if (totalNeeded <= area.height * 0.85) {
      slotH = maxSlotH;
    } else {
      slotH = ((area.height * 0.85) / firstRoundMatches - intraGap) / 2;
      slotH = slotH.clamp(minSlotH, maxSlotH);
    }
    final slotW = colW * 0.82;

    // Text style inside slots: white-fill slot → dark text, OR semi-fill slot → light text
    final slotFillPaint = Paint()..color = pal.slotFill;
    final slotBorderPaint = Paint()..color = pal.slotBorder..style = PaintingStyle.stroke..strokeWidth = 0.5;
    final linePaint = Paint()..color = pal.lineColor.withValues(alpha: 0.5)..strokeWidth = 0.7;
    final teamFs = (slotH * 0.55).clamp(3.0, 6.5);
    final teamStyle = TextStyle(color: pal.textColor, fontSize: teamFs, fontWeight: FontWeight.w700);

    // Build round-by-round: track the center Y of each match so next round can connect
    List<double> prevCenters = [];
    int matchCount = firstRoundMatches;

    for (int r = 0; r < sideRounds; r++) {
      final List<double> roundCenters = [];

      // Compute vertical positions
      List<double> slotYs = [];
      if (r == 0) {
        // First round: distribute evenly across area height
        final totalH = matchCount * (slotH * 2 + intraGap);
        final gap = (area.height - totalH) / (matchCount + 1);
        for (int m = 0; m < matchCount; m++) {
          slotYs.add(area.top + gap * (m + 1) + m * (slotH * 2 + intraGap));
        }
      } else {
        // Later rounds: center between the two matches it receives from
        for (int m = 0; m < matchCount; m++) {
          final idx1 = m * 2;
          final idx2 = m * 2 + 1;
          if (idx2 < prevCenters.length) {
            final midY = (prevCenters[idx1] + prevCenters[idx2]) / 2 - (slotH + intraGap / 2);
            slotYs.add(midY);
          } else if (idx1 < prevCenters.length) {
            slotYs.add(prevCenters[idx1] - (slotH + intraGap / 2));
          }
        }
      }

      for (int m = 0; m < matchCount && m < slotYs.length; m++) {
        final topY = slotYs[m];
        final botY = topY + slotH + intraGap;
        final centerMatchY = (topY + slotH / 2 + botY + slotH / 2) / 2;
        roundCenters.add(centerMatchY);

        // X position
        final slotX = isLeft
            ? area.left + r * colW + (colW - slotW) / 2
            : area.right - (r + 1) * colW + (colW - slotW) / 2;

        // Get team names
        final t1 = _teamName(isLeft, r, m, 0, firstRoundMatches);
        final t2 = _teamName(isLeft, r, m, 1, firstRoundMatches);

        // Draw top slot
        _drawSlot(canvas, slotX, topY, slotW, slotH, t1,
            slotFillPaint, slotBorderPaint, teamStyle, pal);

        // Draw bottom slot
        _drawSlot(canvas, slotX, botY, slotW, slotH, t2,
            slotFillPaint, slotBorderPaint, teamStyle, pal);

        // Connector: vertical line on the advancing side
        final connX = isLeft ? slotX + slotW : slotX;
        canvas.drawLine(
          Offset(connX, topY + slotH / 2),
          Offset(connX, botY + slotH / 2),
          linePaint,
        );

        // Horizontal line from connector toward next round
        if (r < sideRounds - 1) {
          final hLen = (colW - slotW) / 2 + slotW * 0.1;
          final hEnd = isLeft ? connX + hLen : connX - hLen;
          canvas.drawLine(Offset(connX, centerMatchY), Offset(hEnd, centerMatchY), linePaint);
        } else {
          // Last round → line to center edge
          final hEnd = isLeft ? area.right : area.left;
          canvas.drawLine(Offset(connX, centerMatchY), Offset(hEnd, centerMatchY),
              Paint()..color = pal.accentColor.withValues(alpha: 0.6)..strokeWidth = 0.8);
        }

        // Incoming lines from previous round
        if (r > 0 && prevCenters.isNotEmpty) {
          final idx1 = m * 2;
          final idx2 = m * 2 + 1;
          final inX = isLeft ? slotX : slotX + slotW;
          if (idx1 < prevCenters.length) {
            canvas.drawLine(Offset(inX, prevCenters[idx1]), Offset(inX, topY + slotH / 2), linePaint);
          }
          if (idx2 < prevCenters.length) {
            canvas.drawLine(Offset(inX, prevCenters[idx2]), Offset(inX, botY + slotH / 2), linePaint);
          }
        }
      }

      prevCenters = roundCenters;
      matchCount = (matchCount / 2).ceil();
      if (matchCount < 1) matchCount = 1;
    }
  }

  /// Draw a single bracket slot (white-filled rectangle with team name).
  void _drawSlot(Canvas canvas, double x, double y, double w, double h,
      String team, Paint fill, Paint border, TextStyle style, BracketPrintPalette pal) {
    final rect = RRect.fromRectAndRadius(Rect.fromLTWH(x, y, w, h), const Radius.circular(1.5));

    // Winner gets highlighted slot
    final isWinner = team.isNotEmpty &&
        (team.toUpperCase() == championName.toUpperCase() ||
         _trunc(championName).toUpperCase() == team.toUpperCase());

    if (isWinner) {
      canvas.drawRRect(rect, Paint()..color = pal.accentColor.withValues(alpha: 0.25));
      canvas.drawRRect(rect, Paint()
        ..color = pal.accentColor.withValues(alpha: 0.8)
        ..style = PaintingStyle.stroke..strokeWidth = 0.8);
    } else {
      canvas.drawRRect(rect, fill);
      canvas.drawRRect(rect, border);
    }

    if (team.isNotEmpty) {
      final ts = isWinner
          ? style.copyWith(color: pal.championColor, fontWeight: FontWeight.w800)
          : style;
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(x, y, w, h));
      final span = TextSpan(text: team.toUpperCase(), style: ts);
      final tp = TextPainter(text: span, textDirection: TextDirection.ltr, maxLines: 1, ellipsis: '..')
        ..layout(maxWidth: w - 3);
      tp.paint(canvas, Offset(x + 1.5, y + (h - tp.height) / 2));
      canvas.restore();
    }
  }

  // ─── TEAM NAME LOOKUP ──────────────────────────────────────────

  String _teamName(bool isLeft, int round, int match, int slot, int firstRoundMatches) {
    // Round 0: pull from seeded teams list
    if (round == 0) {
      final offset = isLeft ? 0 : teams.length ~/ 2;
      final idx = offset + match * 2 + slot;
      if (idx < teams.length) return _trunc(teams[idx]);
      return '';
    }

    // Later rounds: search picks map
    final side = isLeft ? 'left' : 'right';

    // Try exact slot key
    final key = 'slot_${side}_r${round}_m${match}_team${slot + 1}';
    if (picks.containsKey(key)) return _trunc(picks[key]!);

    // Try team1 fallback (some flows only store one winner per match)
    if (slot == 0) {
      final k1 = 'slot_${side}_r${round}_m${match}_team1';
      if (picks.containsKey(k1)) return _trunc(picks[k1]!);
    }

    // Fuzzy search: any pick matching round + match + side
    for (final e in picks.entries) {
      if (e.key.contains('r$round') && e.key.contains('m$match') && e.key.contains(side)) {
        return _trunc(e.value);
      }
    }

    return '';
  }

  String _trunc(String s) => s.length <= 14 ? s : '${s.substring(0, 12)}..';

  // ─── TEXT UTILITIES ────────────────────────────────────────────

  void _paintText(Canvas canvas, String text, TextStyle style, Offset pos, {bool center = false}) {
    final span = TextSpan(text: text, style: style);
    final tp = TextPainter(text: span, textDirection: TextDirection.ltr)..layout();
    final off = center ? Offset(pos.dx - tp.width / 2, pos.dy - tp.height / 2) : pos;
    tp.paint(canvas, off);
  }

  Size _measure(String text, TextStyle style) {
    final tp = TextPainter(text: TextSpan(text: text, style: style), textDirection: TextDirection.ltr)..layout();
    return Size(tp.width, tp.height);
  }

  int _log2(int n) { int r = 0; while (n > 1) { n ~/= 2; r++; } return r; }

  @override
  bool shouldRepaint(covariant GarmentMockupPainter old) =>
      garmentColor != old.garmentColor || productType != old.productType ||
      teamCount != old.teamCount || printStyle != old.printStyle ||
      bracketTitle != old.bracketTitle || championName != old.championName ||
      teams != old.teams || picks != old.picks;
}
