#!/usr/bin/env bash
# Tests for config/example file changes introduced in this PR:
#   - .env.appstoreconnect.example: added blank lines + "trendn-1"
#   - .env.devices.example: removed "trenddddd"
#   - .gitignore: added blank lines in macOS and Archive sections

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0

ok()   { PASS=$((PASS+1)); echo "  PASS: $1"; }
fail() { FAIL=$((FAIL+1)); echo "  FAIL: $1"; }

echo ""
echo "=== Config File Tests ==="
echo ""

# ---------------------------------------------------------------------------
# .env.appstoreconnect.example
# ---------------------------------------------------------------------------
echo "-- .env.appstoreconnect.example --"

ENV_ASC="$REPO_ROOT/.env.appstoreconnect.example"

# PR added "trendn-1" as new content at the end of the file
grep -qF "trendn-1" "$ENV_ASC" \
  && ok '.env.appstoreconnect.example contains added line "trendn-1"' \
  || fail '.env.appstoreconnect.example is missing added line "trendn-1"'

# PR added blank lines between existing content and "trendn-1"; file must have ≥ 8 lines
LINE_COUNT=$(wc -l < "$ENV_ASC")
[ "$LINE_COUNT" -ge 8 ] \
  && ok ".env.appstoreconnect.example has >= 8 lines (blank lines present, got $LINE_COUNT)" \
  || fail ".env.appstoreconnect.example has $LINE_COUNT lines, expected >= 8"

# "trendn-1" must appear after the API_ISSUER line (not before)
ISSUER_LINE=$(grep -n "API_ISSUER" "$ENV_ASC" | head -1 | cut -d: -f1)
TREND_LINE=$(grep -n "trendn-1"   "$ENV_ASC" | head -1 | cut -d: -f1)
[ -n "$ISSUER_LINE" ] && [ -n "$TREND_LINE" ] && [ "$TREND_LINE" -gt "$ISSUER_LINE" ] \
  && ok '"trendn-1" appears after API_ISSUER line' \
  || fail '"trendn-1" does not appear after API_ISSUER line'

# Blank lines exist between API_ISSUER and trendn-1 (at least one blank line)
BLANK_BETWEEN=$(awk -v s="$ISSUER_LINE" -v e="$TREND_LINE" \
  'NR > s && NR < e && /^[[:space:]]*$/ { count++ } END { print count+0 }' "$ENV_ASC")
[ "$BLANK_BETWEEN" -ge 1 ] \
  && ok "At least one blank line exists between API_ISSUER and trendn-1 ($BLANK_BETWEEN blank lines)" \
  || fail "No blank lines found between API_ISSUER and trendn-1"

# Regression: pre-existing required keys still present after edits
grep -qF "API_KEY=" "$ENV_ASC" \
  && ok '.env.appstoreconnect.example still contains API_KEY=' \
  || fail '.env.appstoreconnect.example is missing API_KEY='

grep -qF "API_ISSUER=" "$ENV_ASC" \
  && ok '.env.appstoreconnect.example still contains API_ISSUER=' \
  || fail '.env.appstoreconnect.example is missing API_ISSUER='

echo ""

# ---------------------------------------------------------------------------
# .env.devices.example
# ---------------------------------------------------------------------------
echo "-- .env.devices.example --"

ENV_DEV="$REPO_ROOT/.env.devices.example"

# PR removed "trenddddd" — it must no longer be present
grep -qF "trenddddd" "$ENV_DEV" \
  && fail '.env.devices.example still contains removed line "trenddddd"' \
  || ok '.env.devices.example does not contain removed line "trenddddd"'

# File must not be empty after the removal
[ -s "$ENV_DEV" ] \
  && ok ".env.devices.example is non-empty after removal" \
  || fail ".env.devices.example is empty after removal"

# Regression: IOS_DEVICE_ID key must still be present
grep -qF "IOS_DEVICE_ID=" "$ENV_DEV" \
  && ok '.env.devices.example still contains IOS_DEVICE_ID=' \
  || fail '.env.devices.example is missing IOS_DEVICE_ID='

# Negative: no other stray non-comment, non-variable lines remain
STRAY=$(grep -vE '^[[:space:]]*$|^[[:space:]]*#|^[A-Z_]+=.*' "$ENV_DEV" || true)
[ -z "$STRAY" ] \
  && ok ".env.devices.example contains only valid lines (variables, comments, blanks)" \
  || fail ".env.devices.example contains unexpected stray lines: $STRAY"

echo ""

# ---------------------------------------------------------------------------
# .gitignore
# ---------------------------------------------------------------------------
echo "-- .gitignore --"

GITIGNORE="$REPO_ROOT/.gitignore"

# PR added blank lines before .DS_Store in the macOS section; .DS_Store must still be present
grep -qF ".DS_Store" "$GITIGNORE" \
  && ok '.gitignore contains .DS_Store after blank-line additions' \
  || fail '.gitignore is missing .DS_Store'

# Verify .DS_Store appears under the macOS comment (not accidentally relocated)
MACOS_LINE=$(grep -n "# macOS" "$GITIGNORE" | head -1 | cut -d: -f1)
DS_LINE=$(grep -n "\.DS_Store" "$GITIGNORE" | head -1 | cut -d: -f1)
[ -n "$MACOS_LINE" ] && [ -n "$DS_LINE" ] && [ "$DS_LINE" -gt "$MACOS_LINE" ] \
  && ok '.DS_Store appears after the "# macOS" comment' \
  || fail '.DS_Store does not appear after the "# macOS" comment'

# PR added blank lines after _archive/ entry; _archive/ must still be present
grep -qF "_archive/" "$GITIGNORE" \
  && ok '.gitignore contains _archive/ after blank-line additions' \
  || fail '.gitignore is missing _archive/'

# Blank lines added in the macOS section (between "# macOS" and ".DS_Store")
BLANK_MACOS=$(awk -v s="$MACOS_LINE" -v e="$DS_LINE" \
  'NR > s && NR < e && /^[[:space:]]*$/ { count++ } END { print count+0 }' "$GITIGNORE")
[ "$BLANK_MACOS" -ge 1 ] \
  && ok "Blank lines exist between '# macOS' comment and .DS_Store ($BLANK_MACOS blank lines)" \
  || fail "No blank lines found between '# macOS' comment and .DS_Store"

# Blank lines added after _archive/ entry (PR added 3 blank lines there)
ARCHIVE_LINE=$(grep -n "_archive/" "$GITIGNORE" | head -1 | cut -d: -f1)
MISC_LINE=$(grep -n "# Misc" "$GITIGNORE" | head -1 | cut -d: -f1)
BLANK_ARCHIVE=$(awk -v s="$ARCHIVE_LINE" -v e="$MISC_LINE" \
  'NR > s && NR < e && /^[[:space:]]*$/ { count++ } END { print count+0 }' "$GITIGNORE")
[ "$BLANK_ARCHIVE" -ge 1 ] \
  && ok "Blank lines exist between _archive/ and '# Misc' comment ($BLANK_ARCHIVE blank lines)" \
  || fail "No blank lines found between _archive/ and '# Misc' comment"

# Regression: critical patterns still present and functional
for pattern in ".dart_tool/" "build/" ".DS_Store" "_archive/" "*.log" "*.tmp" ".idea/" ".vscode/"; do
  grep -qF "$pattern" "$GITIGNORE" \
    && ok ".gitignore retains pattern: $pattern" \
    || fail ".gitignore is missing pattern: $pattern"
done

echo ""

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
TOTAL=$((PASS+FAIL))
echo "=== Results: $PASS/$TOTAL passed ==="
echo ""

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
