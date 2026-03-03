import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Manages the charity escrow lifecycle for tournament charity pots.
///
/// Escrow States:
///   1. **pending_selection** — Winner has been crowned; they have 30 days
///      to pick a charity from the BMB-approved list.
///   2. **allocated** — Winner chose a charity; funds are earmarked and
///      queued for payout via Tremendous.
///   3. **released_to_bmb** — 30-day window expired without a selection,
///      OR the winner picked "Let BMB Choose". BMB selects a charity on
///      their behalf (funds remain charitable, never go to BMB profit).
///
/// 30-Day Auto-Release:
///   If the winner does not choose a charity within 30 days of the
///   bracket ending, the escrow automatically transitions to
///   `released_to_bmb`.
///
/// In production: escrow state would be stored server-side in Firestore
/// and a Cloud Function would handle the 30-day auto-release cron.
class CharityEscrowService {
  CharityEscrowService._();
  static final CharityEscrowService instance = CharityEscrowService._();

  // ─── Keys ────────────────────────────────────────────────────────────
  static const _kEscrows = 'bmb_charity_escrows';

  // ─── Constants ───────────────────────────────────────────────────────
  /// How long the winner has to choose a charity.
  static const Duration selectionWindow = Duration(days: 30);

  // ═══════════════════════════════════════════════════════════════════
  // CREATE / READ
  // ═══════════════════════════════════════════════════════════════════

  /// Create a new escrow when a charity bracket ends and a winner is crowned.
  Future<CharityEscrow> createEscrow({
    required String bracketId,
    required String bracketName,
    required String winnerId,
    required String winnerName,
    required int potCredits,
    required double netDonationDollars,
  }) async {
    final now = DateTime.now();
    final escrow = CharityEscrow(
      bracketId: bracketId,
      bracketName: bracketName,
      winnerId: winnerId,
      winnerName: winnerName,
      potCredits: potCredits,
      netDonationDollars: netDonationDollars,
      state: EscrowState.pendingSelection,
      createdAt: now,
      expiresAt: now.add(selectionWindow),
      selectedCharity: null,
      stateChangedAt: now,
    );

    final escrows = await _loadAll();
    escrows[bracketId] = escrow;
    await _saveAll(escrows);

    if (kDebugMode) {
      debugPrint('[CharityEscrow] Created escrow for bracket $bracketId. '
          'Winner: $winnerName, Pot: $potCredits credits, '
          'Expires: ${escrow.expiresAt}');
    }

    return escrow;
  }

  /// Get a specific escrow by bracket ID.
  Future<CharityEscrow?> getEscrow(String bracketId) async {
    final escrows = await _loadAll();
    final escrow = escrows[bracketId];
    if (escrow == null) return null;

    // Check if auto-release should trigger
    if (escrow.state == EscrowState.pendingSelection &&
        DateTime.now().isAfter(escrow.expiresAt)) {
      return await _autoRelease(escrow);
    }
    return escrow;
  }

  /// Get all escrows (optionally filtered by state).
  Future<List<CharityEscrow>> getAllEscrows({EscrowState? filterState}) async {
    final escrows = await _loadAll();
    final results = <CharityEscrow>[];

    for (final entry in escrows.entries) {
      var escrow = entry.value;
      // Auto-release check
      if (escrow.state == EscrowState.pendingSelection &&
          DateTime.now().isAfter(escrow.expiresAt)) {
        escrow = await _autoRelease(escrow);
      }
      if (filterState == null || escrow.state == filterState) {
        results.add(escrow);
      }
    }

    // Sort by creation date descending
    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  /// Get escrows where the given user is the winner.
  Future<List<CharityEscrow>> getEscrowsForWinner(String winnerId) async {
    final all = await getAllEscrows();
    return all.where((e) => e.winnerId == winnerId).toList();
  }

  // ═══════════════════════════════════════════════════════════════════
  // STATE TRANSITIONS
  // ═══════════════════════════════════════════════════════════════════

  /// Winner selects a charity from the approved list.
  /// Transitions: pending_selection → allocated
  Future<CharityEscrow> selectCharity({
    required String bracketId,
    required String charityName,
    required String charityId,
  }) async {
    final escrows = await _loadAll();
    final escrow = escrows[bracketId];

    if (escrow == null) {
      throw Exception('Escrow not found for bracket $bracketId');
    }
    if (escrow.state != EscrowState.pendingSelection) {
      throw Exception('Escrow is not in pending_selection state');
    }

    final updated = escrow.copyWith(
      state: EscrowState.allocated,
      selectedCharity: charityName,
      selectedCharityId: charityId,
      stateChangedAt: DateTime.now(),
    );

    escrows[bracketId] = updated;
    await _saveAll(escrows);

    if (kDebugMode) {
      debugPrint('[CharityEscrow] Bracket $bracketId: '
          'Winner selected "$charityName". State → allocated.');
    }

    return updated;
  }

  /// Winner (or system) chooses "Let BMB Choose" — transitions to released_to_bmb.
  Future<CharityEscrow> letBmbChoose(String bracketId) async {
    final escrows = await _loadAll();
    final escrow = escrows[bracketId];

    if (escrow == null) {
      throw Exception('Escrow not found for bracket $bracketId');
    }
    if (escrow.state != EscrowState.pendingSelection) {
      throw Exception('Escrow is not in pending_selection state');
    }

    final updated = escrow.copyWith(
      state: EscrowState.releasedToBmb,
      selectedCharity: 'BMB Choice',
      stateChangedAt: DateTime.now(),
    );

    escrows[bracketId] = updated;
    await _saveAll(escrows);

    if (kDebugMode) {
      debugPrint('[CharityEscrow] Bracket $bracketId: '
          '"Let BMB Choose" selected. State → released_to_bmb.');
    }

    return updated;
  }

  /// Admin: mark an escrow as having its donation processed.
  Future<CharityEscrow> markDonationProcessed(String bracketId) async {
    final escrows = await _loadAll();
    final escrow = escrows[bracketId];

    if (escrow == null) {
      throw Exception('Escrow not found for bracket $bracketId');
    }

    final updated = escrow.copyWith(
      donationProcessed: true,
      stateChangedAt: DateTime.now(),
    );

    escrows[bracketId] = updated;
    await _saveAll(escrows);

    if (kDebugMode) {
      debugPrint('[CharityEscrow] Bracket $bracketId: Donation processed.');
    }

    return updated;
  }

  // ═══════════════════════════════════════════════════════════════════
  // QUERIES
  // ═══════════════════════════════════════════════════════════════════

  /// Count of escrows about to expire (within 7 days).
  Future<int> getExpiringEscrowCount() async {
    final all =
        await getAllEscrows(filterState: EscrowState.pendingSelection);
    final soon = DateTime.now().add(const Duration(days: 7));
    return all.where((e) => e.expiresAt.isBefore(soon)).length;
  }

  /// Total dollars currently in escrow (pending_selection + allocated).
  Future<double> getTotalInEscrow() async {
    final all = await getAllEscrows();
    double total = 0;
    for (final e in all) {
      if (e.state != EscrowState.releasedToBmb || !e.donationProcessed) {
        total += e.netDonationDollars;
      }
    }
    return total;
  }

  // ═══════════════════════════════════════════════════════════════════
  // PRIVATE — auto-release + persistence
  // ═══════════════════════════════════════════════════════════════════

  /// Automatically release an expired escrow to BMB.
  Future<CharityEscrow> _autoRelease(CharityEscrow escrow) async {
    final updated = escrow.copyWith(
      state: EscrowState.releasedToBmb,
      selectedCharity: 'BMB Choice (30-day auto-release)',
      stateChangedAt: DateTime.now(),
    );

    final escrows = await _loadAll();
    escrows[escrow.bracketId] = updated;
    await _saveAll(escrows);

    if (kDebugMode) {
      debugPrint('[CharityEscrow] Bracket ${escrow.bracketId}: '
          '30-day window expired. Auto-released to BMB.');
    }

    return updated;
  }

  Future<Map<String, CharityEscrow>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kEscrows);
    if (raw == null || raw.isEmpty) return {};

    try {
      final Map<String, dynamic> jsonMap = jsonDecode(raw);
      return jsonMap.map(
          (k, v) => MapEntry(k, CharityEscrow.fromJson(v)));
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CharityEscrow] Failed to parse escrows: $e');
      }
      return {};
    }
  }

  Future<void> _saveAll(Map<String, CharityEscrow> escrows) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonMap =
        escrows.map((k, v) => MapEntry(k, v.toJson()));
    await prefs.setString(_kEscrows, jsonEncode(jsonMap));
  }
}

// ═══════════════════════════════════════════════════════════════════
// DATA MODELS
// ═══════════════════════════════════════════════════════════════════

enum EscrowState {
  /// Winner crowned — waiting for charity selection (up to 30 days).
  pendingSelection,
  /// Charity selected — funds earmarked for payout.
  allocated,
  /// 30-day expired or winner chose "Let BMB Choose" — BMB picks charity.
  releasedToBmb,
}

class CharityEscrow {
  final String bracketId;
  final String bracketName;
  final String winnerId;
  final String winnerName;
  final int potCredits;
  final double netDonationDollars;
  final EscrowState state;
  final DateTime createdAt;
  final DateTime expiresAt;
  final String? selectedCharity;
  final String? selectedCharityId;
  final DateTime stateChangedAt;
  final bool donationProcessed;

  const CharityEscrow({
    required this.bracketId,
    required this.bracketName,
    required this.winnerId,
    required this.winnerName,
    required this.potCredits,
    required this.netDonationDollars,
    required this.state,
    required this.createdAt,
    required this.expiresAt,
    this.selectedCharity,
    this.selectedCharityId,
    required this.stateChangedAt,
    this.donationProcessed = false,
  });

  /// Days remaining before auto-release.
  int get daysRemaining {
    final remaining = expiresAt.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Whether the selection window has expired.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// Human-readable state label.
  String get stateLabel {
    switch (state) {
      case EscrowState.pendingSelection:
        return 'Awaiting Charity Selection';
      case EscrowState.allocated:
        return 'Charity Selected';
      case EscrowState.releasedToBmb:
        return 'Released to BMB';
    }
  }

  CharityEscrow copyWith({
    EscrowState? state,
    String? selectedCharity,
    String? selectedCharityId,
    DateTime? stateChangedAt,
    bool? donationProcessed,
  }) {
    return CharityEscrow(
      bracketId: bracketId,
      bracketName: bracketName,
      winnerId: winnerId,
      winnerName: winnerName,
      potCredits: potCredits,
      netDonationDollars: netDonationDollars,
      state: state ?? this.state,
      createdAt: createdAt,
      expiresAt: expiresAt,
      selectedCharity: selectedCharity ?? this.selectedCharity,
      selectedCharityId: selectedCharityId ?? this.selectedCharityId,
      stateChangedAt: stateChangedAt ?? this.stateChangedAt,
      donationProcessed: donationProcessed ?? this.donationProcessed,
    );
  }

  Map<String, dynamic> toJson() => {
        'bracketId': bracketId,
        'bracketName': bracketName,
        'winnerId': winnerId,
        'winnerName': winnerName,
        'potCredits': potCredits,
        'netDonationDollars': netDonationDollars,
        'state': state.name,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'selectedCharity': selectedCharity,
        'selectedCharityId': selectedCharityId,
        'stateChangedAt': stateChangedAt.toIso8601String(),
        'donationProcessed': donationProcessed,
      };

  factory CharityEscrow.fromJson(Map<String, dynamic> json) {
    return CharityEscrow(
      bracketId: json['bracketId'] as String,
      bracketName: json['bracketName'] as String,
      winnerId: json['winnerId'] as String,
      winnerName: json['winnerName'] as String,
      potCredits: json['potCredits'] as int,
      netDonationDollars: (json['netDonationDollars'] as num).toDouble(),
      state: EscrowState.values.firstWhere(
          (e) => e.name == json['state'],
          orElse: () => EscrowState.pendingSelection),
      createdAt: DateTime.parse(json['createdAt'] as String),
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      selectedCharity: json['selectedCharity'] as String?,
      selectedCharityId: json['selectedCharityId'] as String?,
      stateChangedAt: DateTime.parse(json['stateChangedAt'] as String),
      donationProcessed: json['donationProcessed'] as bool? ?? false,
    );
  }
}
