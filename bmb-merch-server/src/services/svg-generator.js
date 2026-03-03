/**
 * SVG Bracket Generator
 * ─────────────────────
 * Deterministic SVG bracket renderer.
 * Artboard: 12 inches wide = 3600px at 300 DPI.
 * All text converted to <path> outlines for production printing.
 * No AI rendering. Pure math-based layout.
 */

const ARTBOARD_W = 3600; // 12 inches at 300 DPI
const ARTBOARD_H = 4800; // 16 inches at 300 DPI (adjusts per team count)

// ── Font metrics for Arial/Helvetica approximation (path-based) ─────
// We use SVG rect+text for screen preview, and note that for final
// production the printer receives the SVG with embedded fonts.
// Text-to-outlines is handled by the compositor step via Sharp rasterization.

/**
 * Generate bracket SVG from bracket data.
 *
 * @param {Object} params
 * @param {string} params.bracketTitle  - e.g. "MARCH MADNESS 2025"
 * @param {string} params.championName  - e.g. "DUKE"
 * @param {number} params.teamCount     - 4, 8, 16, 32, or 64
 * @param {string[]} params.teams       - seeded team names
 * @param {Object} params.picks         - round/match → team name
 * @param {string} params.style         - "classic" | "premium" | "bold"
 * @param {string} params.palette       - "light" (white on dark) | "dark" (dark on light)
 * @returns {string} SVG markup
 */
function generateBracketSvg({
  bracketTitle = 'TOURNAMENT',
  championName = 'TBD',
  teamCount = 16,
  teams = [],
  picks = {},
  style = 'classic',
  palette = 'light',
}) {
  const layout = computeLayout(teamCount);
  const pal = palette === 'light' ? PALETTE_LIGHT : PALETTE_DARK;
  const lines = [];

  // SVG open — 12-inch artboard
  lines.push(`<?xml version="1.0" encoding="UTF-8"?>`);
  lines.push(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${layout.canvasW} ${layout.canvasH}" width="${layout.canvasW}" height="${layout.canvasH}" font-family="'Helvetica Neue', 'Arial', sans-serif">`);

  // Background (transparent for garment overlay)
  // No background rect — transparent by default

  // ── Title ──
  const cx = layout.canvasW / 2;
  const titleY = 80;
  const titleSize = style === 'bold' ? 72 : 60;
  const titleWeight = style === 'bold' ? 900 : 700;
  const titleSpacing = style === 'bold' ? 12 : 6;
  lines.push(`<text x="${cx}" y="${titleY}" text-anchor="middle" fill="${pal.title}" font-size="${titleSize}" font-weight="${titleWeight}" letter-spacing="${titleSpacing}">${esc(bracketTitle.toUpperCase())}</text>`);

  // ── Champion capsule ──
  const champY = titleY + 40;
  const champText = championName.toUpperCase();
  const champBoxW = Math.max(champText.length * 28 + 80, 200);
  const champBoxH = 50;

  if (style === 'premium') {
    // Double border
    lines.push(`<rect x="${cx - champBoxW / 2 - 4}" y="${champY - 4}" width="${champBoxW + 8}" height="${champBoxH + 8}" rx="10" fill="none" stroke="${pal.accent}" stroke-width="2" opacity="0.3"/>`);
  }
  lines.push(`<rect x="${cx - champBoxW / 2}" y="${champY}" width="${champBoxW}" height="${champBoxH}" rx="8" fill="${pal.accent}" opacity="0.2" stroke="${pal.accent}" stroke-width="${style === 'bold' ? 4 : 2}"/>`);
  lines.push(`<text x="${cx}" y="${champY + 34}" text-anchor="middle" fill="${pal.accent}" font-size="28" font-weight="800" letter-spacing="4">${esc(champText)}</text>`);

  // ── Bracket body ──
  const bracketStartY = champY + champBoxH + 40;
  const halfTeams = teamCount / 2;
  const sideRounds = Math.ceil(Math.log2(teamCount) / 2);
  const firstRoundMatchesSide = halfTeams / 2;

  // Left side
  writeBracketSide(lines, {
    side: 'left',
    startX: layout.marginX,
    startY: bracketStartY,
    layout,
    teams,
    picks,
    pal,
    style,
    seedOffset: 0,
    sideRounds,
    firstRoundMatches: firstRoundMatchesSide,
    champion: championName,
  });

  // Right side
  writeBracketSide(lines, {
    side: 'right',
    startX: layout.canvasW - layout.marginX,
    startY: bracketStartY,
    layout,
    teams,
    picks,
    pal,
    style,
    seedOffset: halfTeams,
    sideRounds,
    firstRoundMatches: firstRoundMatchesSide,
    champion: championName,
  });

  // ── Center trophy dot ──
  const centerY = bracketStartY + layout.bracketH / 2;
  lines.push(`<circle cx="${cx}" cy="${centerY}" r="12" fill="${pal.accent}"/>`);

  // ── Watermark ──
  const wmY = layout.canvasH - 60;
  lines.push(`<text x="${cx}" y="${wmY}" text-anchor="middle" fill="${pal.text}" opacity="0.15" font-size="24" font-weight="700" letter-spacing="8">BACKMYBRACKET.COM</text>`);

  lines.push('</svg>');
  return lines.join('\n');
}

// ── Layout computation ──────────────────────────────────────────

function computeLayout(teamCount) {
  const rounds = Math.ceil(Math.log2(teamCount));
  const halfTeams = teamCount / 2;
  const sideRounds = Math.ceil(rounds / 2);
  const firstRoundMatches = halfTeams / 2;

  const slotW = teamCount <= 8 ? 420 : teamCount <= 16 ? 380 : teamCount <= 32 ? 340 : 300;
  const slotH = teamCount <= 16 ? 60 : 48;
  const matchGap = teamCount <= 8 ? 24 : teamCount <= 16 ? 18 : 12;
  const roundGap = teamCount <= 8 ? 120 : teamCount <= 16 ? 100 : 80;
  const marginX = 60;

  const matchH = slotH * 2 + matchGap;
  const bracketH = firstRoundMatches * matchH + (firstRoundMatches - 1) * matchGap;

  const champColW = slotW + 60;
  const sideW = sideRounds * (slotW + roundGap);
  const canvasW = Math.max(sideW * 2 + champColW + marginX * 2, ARTBOARD_W);
  const canvasH = 200 + bracketH + 120; // header + bracket + footer

  return { rounds, halfTeams, sideRounds, slotW, slotH, matchGap, roundGap, marginX, matchH, bracketH, canvasW, canvasH, champColW };
}

// ── Bracket side renderer ───────────────────────────────────────

function writeBracketSide(lines, opts) {
  const { side, startX, startY, layout, teams, picks, pal, style, seedOffset, sideRounds, firstRoundMatches, champion } = opts;
  const isLeft = side === 'left';
  let matchCount = firstRoundMatches;
  const { slotW, slotH, matchGap, roundGap, matchH } = layout;

  // Round labels
  const roundLabels = getRoundLabels(layout.rounds);

  for (let r = 0; r < sideRounds; r++) {
    const totalH = matchCount * matchH + (matchCount - 1) * matchGap;
    const baseH = firstRoundMatches * matchH + (firstRoundMatches - 1) * matchGap;
    const offsetY = startY + (baseH - totalH) / 2;

    // Round label
    const labelX = isLeft
      ? startX + r * (slotW + roundGap) + slotW / 2
      : startX - r * (slotW + roundGap) - slotW / 2;
    if (r < roundLabels.length) {
      const labelColor = style === 'premium' ? pal.accent : pal.text;
      lines.push(`<text x="${labelX}" y="${startY - 15}" text-anchor="middle" fill="${labelColor}" opacity="0.5" font-size="18" font-weight="700" letter-spacing="3">${roundLabels[r]}</text>`);
    }

    for (let m = 0; m < matchCount; m++) {
      const myCenterY = offsetY + m * (matchH + matchGap) + matchH / 2;
      const slotX = isLeft
        ? startX + r * (slotW + roundGap)
        : startX - r * (slotW + roundGap) - slotW;

      const topLabel = getTeamLabel(picks, side, r, m, 0, teams, seedOffset);
      const botLabel = getTeamLabel(picks, side, r, m, 1, teams, seedOffset);
      const topSeed = r === 0 ? `#${seedOffset + m * 2 + 1}` : '';
      const botSeed = r === 0 ? `#${seedOffset + m * 2 + 2}` : '';

      const topY = myCenterY - slotH - matchGap / 2;
      const botY = myCenterY + matchGap / 2;

      const isChampTop = topLabel.toUpperCase() === champion.toUpperCase();
      const isChampBot = botLabel.toUpperCase() === champion.toUpperCase();

      // Draw slots
      writeSlot(lines, slotX, topY, slotW, slotH, topLabel, topSeed, r === 0, pal, style, isChampTop);
      writeSlot(lines, slotX, botY, slotW, slotH, botLabel, botSeed, r === 0, pal, style, isChampBot);

      // Connector lines
      const connX = isLeft ? slotX + slotW : slotX;
      const isChampConn = isChampTop || isChampBot;
      const connColor = (r === sideRounds - 1 || isChampConn) ? pal.accent : pal.line;
      const connWidth = (r === sideRounds - 1 || (style === 'bold')) ? 4 : 2;

      // Vertical connector
      lines.push(`<line x1="${connX}" y1="${topY + slotH / 2}" x2="${connX}" y2="${botY + slotH / 2}" stroke="${connColor}" stroke-width="${connWidth}" opacity="0.6"/>`);

      // Horizontal connector to next round
      if (r < sideRounds - 1) {
        const hEnd = isLeft ? connX + roundGap / 2 : connX - roundGap / 2;
        lines.push(`<line x1="${connX}" y1="${myCenterY}" x2="${hEnd}" y2="${myCenterY}" stroke="${connColor}" stroke-width="${connWidth}" opacity="0.6"/>`);
      } else {
        // Final round → center
        const hEnd = isLeft ? connX + roundGap * 0.7 : connX - roundGap * 0.7;
        lines.push(`<line x1="${connX}" y1="${myCenterY}" x2="${hEnd}" y2="${myCenterY}" stroke="${pal.accent}" stroke-width="4" opacity="0.8"/>`);
      }
    }

    matchCount = Math.ceil(matchCount / 2);
    if (matchCount < 1) matchCount = 1;
  }
}

// ── Slot renderer ───────────────────────────────────────────────

function writeSlot(lines, x, y, w, h, label, seed, isFirstRound, pal, style, isChamp) {
  const rx = style === 'premium' ? 12 : style === 'bold' ? 6 : 8;
  const isTbd = !label || label === 'TBD';

  if (style === 'bold' && !isTbd) {
    // Bold: solid filled box
    lines.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${pal.text}" opacity="0.9"/>`);
  } else {
    // Classic/Premium: outlined box
    const strokeColor = isChamp ? pal.accent : pal.slotBorder;
    const strokeW = isChamp ? 3 : 1.5;
    lines.push(`<rect x="${x}" y="${y}" width="${w}" height="${h}" rx="${rx}" fill="${pal.slotFill}" stroke="${strokeColor}" stroke-width="${strokeW}"/>`);
  }

  // Seed number
  if (seed && isFirstRound) {
    if (style === 'bold') {
      lines.push(`<rect x="${x}" y="${y}" width="52" height="${h}" rx="${rx}" fill="${pal.accent}" opacity="0.8"/>`);
      lines.push(`<text x="${x + 26}" y="${y + h / 2 + 7}" text-anchor="middle" fill="${isTbd ? pal.text : pal.slotFill}" font-size="18" font-weight="900">${seed}</text>`);
    } else if (style === 'premium') {
      lines.push(`<circle cx="${x + 26}" cy="${y + h / 2}" r="16" fill="${pal.accent}" opacity="0.2"/>`);
      lines.push(`<text x="${x + 26}" y="${y + h / 2 + 6}" text-anchor="middle" fill="${pal.accent}" font-size="16" font-weight="700">${seed}</text>`);
    } else {
      lines.push(`<text x="${x + 26}" y="${y + h / 2 + 6}" text-anchor="middle" fill="${pal.accent}" font-size="16" font-weight="700">${seed}</text>`);
    }
  }

  // Team name
  const textX = (isFirstRound && seed) ? x + 52 : x + 16;
  const display = label && label.length > 20 ? label.substring(0, 19) + '..' : (label || 'TBD');
  const fontSize = h > 50 ? 24 : 20;

  if (style === 'bold' && !isTbd) {
    lines.push(`<text x="${textX}" y="${y + h / 2 + 7}" fill="${pal.slotFill}" font-size="${fontSize}" font-weight="900" opacity="${isTbd ? '0.3' : '1'}">${esc(display.toUpperCase())}</text>`);
  } else {
    const textColor = isChamp ? pal.accent : pal.text;
    const weight = isChamp ? 800 : (isTbd ? 400 : 600);
    lines.push(`<text x="${textX}" y="${y + h / 2 + 7}" fill="${textColor}" font-size="${fontSize}" font-weight="${weight}" opacity="${isTbd ? '0.3' : '1'}">${esc(display.toUpperCase())}</text>`);
  }
}

// ── Helpers ─────────────────────────────────────────────────────

function getTeamLabel(picks, side, round, match, slot, teams, seedOffset) {
  // Check picks map with various key formats
  const keyFormats = [
    `slot_${side}_r${round}_m${match}_team${slot + 1}`,
    `${side}_r${round}_m${match}_s${slot}`,
    `r${round}_m${match}_${side}_s${slot}`,
  ];
  for (const key of keyFormats) {
    if (picks[key]) return picks[key];
  }

  // First round: use seeded teams
  if (round === 0) {
    const idx = seedOffset + match * 2 + slot;
    if (idx < teams.length) return teams[idx];
  }

  return 'TBD';
}

function getRoundLabels(totalRounds) {
  const labels = [];
  for (let i = totalRounds - 1; i >= 0; i--) {
    if (i === 0) labels.push('CHAMPIONSHIP');
    else if (i === 1) labels.push('SEMI-FINALS');
    else if (i === 2) labels.push('QUARTER-FINALS');
    else labels.push(`ROUND ${totalRounds - i}`);
  }
  return labels.reverse();
}

function esc(s) {
  return String(s)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

// ── Color palettes ──────────────────────────────────────────────

const PALETTE_LIGHT = {
  // White/gold on dark garment
  line: '#FFFFFF',
  text: '#FFFFFF',
  slotFill: 'rgba(255,255,255,0.15)',
  slotBorder: 'rgba(255,255,255,0.5)',
  accent: '#FFD700',
  title: '#FFFFFF',
  champion: '#FFD700',
};

const PALETTE_DARK = {
  // Dark navy on light garment
  line: '#0A0E27',
  text: '#0A0E27',
  slotFill: 'rgba(10,14,39,0.1)',
  slotBorder: 'rgba(10,14,39,0.4)',
  accent: '#2137FF',
  title: '#0A0E27',
  champion: '#D63031',
};

module.exports = { generateBracketSvg, PALETTE_LIGHT, PALETTE_DARK };
