// Charity Tournament Credits Policy:
// BMB takes a platform fee (default 10%) from the total charity pot.
// The remaining credits are converted to dollars via Tremendous and
// donated to the charity chosen by the tournament winner.
// Credits NEVER go into the winner's personal BMB account.

import 'package:bmb_mobile/features/bracket_builder/data/models/created_bracket.dart';

class CharityService {
  static final CharityService _instance = CharityService._internal();
  factory CharityService() => _instance;
  CharityService._internal();

  // ═══════════════════════════════════════════════════════════════
  //  CONSTANTS
  // ═══════════════════════════════════════════════════════════════

  /// Default BMB platform fee percentage
  static const double defaultBmbFeePercent = 10.0;

  /// Credit-to-dollar conversion: 1 credit = $0.10
  static const double creditsToDoller = 0.10;

  // ═══════════════════════════════════════════════════════════════
  //  DOLLAR / CREDIT CONVERSION
  // ═══════════════════════════════════════════════════════════════

  /// Convert dollars to BMB credits (e.g. $450 → 4,500 credits)
  static int dollarsToCredits(double dollars) => (dollars / creditsToDoller).round();

  /// Convert BMB credits to dollars (e.g. 4,500 credits → $450)
  static double creditsToDollars(int credits) => credits * creditsToDoller;

  /// Format credits with comma separators
  static String formatCredits(int credits) {
    return credits.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
  }

  // ═══════════════════════════════════════════════════════════════
  //  POT MANAGEMENT
  // ═══════════════════════════════════════════════════════════════

  /// Calculate BMB's fee from the charity pot
  static int calculateBmbFee(int potCredits, {double feePercent = defaultBmbFeePercent}) {
    return (potCredits * feePercent / 100).round();
  }

  /// Calculate net donation (pot minus BMB fee)
  static int calculateNetDonation(int potCredits, {double feePercent = defaultBmbFeePercent}) {
    return potCredits - calculateBmbFee(potCredits, feePercent: feePercent);
  }

  /// Record a contribution to the charity pot.
  /// Returns an updated bracket with the new contribution added.
  static CreatedBracket addContribution({
    required CreatedBracket bracket,
    required String userId,
    required String userName,
    required int credits,
  }) {
    final contribution = CharityContribution(
      userId: userId,
      userName: userName,
      credits: credits,
      contributedAt: DateTime.now(),
    );
    final updatedContributions = [...bracket.charityContributions, contribution];
    final newPotTotal = bracket.charityPotCredits + credits;

    return bracket.copyWith(
      charityPotCredits: newPotTotal,
      charityContributions: updatedContributions,
    );
  }

  /// Validate that a contribution meets the minimum
  static bool isValidContribution(int credits, int minContribution) {
    return credits >= minContribution;
  }

  /// Calculate goal progress (0.0 to 1.0+; can exceed 1.0)
  static double calculateGoalProgress(int potCredits, double goalDollars) {
    if (goalDollars <= 0) return 0;
    final goalCredits = dollarsToCredits(goalDollars);
    return goalCredits > 0 ? potCredits / goalCredits : 0;
  }

  // ═══════════════════════════════════════════════════════════════
  //  RECEIPT GENERATION
  // ═══════════════════════════════════════════════════════════════

  /// Generate a donation receipt summary for the completed bracket
  static CharityReceipt generateReceipt({
    required String bracketId,
    required String bracketName,
    required String charityName,
    required String? charityGoal,
    required String hostName,
    required int totalPlayers,
    required int potCredits,
    required double bmbFeePercent,
  }) {
    final bmbFee = calculateBmbFee(potCredits, feePercent: bmbFeePercent);
    final netDonation = potCredits - bmbFee;

    return CharityReceipt(
      bracketId: bracketId,
      bracketName: bracketName,
      charityName: charityName,
      charityGoal: charityGoal,
      hostName: hostName,
      totalPlayers: totalPlayers,
      creditsPerPlayer: totalPlayers > 0 ? potCredits ~/ totalPlayers : 0,
      totalCreditsRaised: potCredits,
      platformFeeTotal: bmbFee,
      charityCreditsTotal: netDonation,
      generatedAt: DateTime.now(),
    );
  }

  /// Check if bracket is a charity bracket
  static bool isCharityBracket(String prizeType) => prizeType == 'charity';

  // ═══════════════════════════════════════════════════════════════
  //  LEGAL DISCLAIMERS
  // ═══════════════════════════════════════════════════════════════

  /// Get charity disclaimer text
  static String get disclaimer =>
      'BackMyBracket facilitates charity fundraising through tournament play. '
      'BMB collects a 10% platform fee from the total charity pot. '
      'The remaining balance is donated to the charity selected by the tournament winner '
      'via Tremendous, a third-party rewards platform. '
      'BMB does not directly hold or transfer charitable funds \u2014 all donations '
      'are processed through Tremendous\u2019s charity network. '
      'BMB is not a registered charity or payment processor for donations.';

  /// Get short disclaimer for UI
  static String get shortDisclaimer =>
      'BMB takes a 10% platform fee. Remaining pot is donated to the winner\u2019s chosen charity via Tremendous.';

  /// Get ToS charity clause
  static String get tosClause =>
      '7. CHARITY TOURNAMENTS\n\n'
      '7.1 BMB provides a "Play for Their Charity" feature where participants '
      'contribute credits to a shared charity pot instead of receiving personal rewards.\n\n'
      '7.2 BMB collects a 10% platform fee from the total charity pot.\n\n'
      '7.3 The tournament winner selects a charity from BMB\u2019s partner list '
      '(powered by Tremendous). The net pot (after BMB\u2019s fee) is donated '
      'directly to that charity.\n\n'
      '7.4 Credits from the charity pot NEVER enter the winner\u2019s personal '
      'BMB account. The donation is processed directly through Tremendous.\n\n'
      '7.5 BMB displays the charity name, pot total, and donation receipt for '
      'full transparency.\n\n'
      '7.6 Users acknowledge that BMB bears no liability for the charity\u2019s '
      'use of donated funds.';
}

/// Represents a generated donation receipt
class CharityReceipt {
  final String bracketId;
  final String bracketName;
  final String charityName;
  final String? charityGoal;
  final String hostName;
  final int totalPlayers;
  final int creditsPerPlayer;
  final int totalCreditsRaised;
  final int platformFeeTotal;
  final int charityCreditsTotal;
  final DateTime generatedAt;

  const CharityReceipt({
    required this.bracketId,
    required this.bracketName,
    required this.charityName,
    this.charityGoal,
    required this.hostName,
    required this.totalPlayers,
    required this.creditsPerPlayer,
    required this.totalCreditsRaised,
    required this.platformFeeTotal,
    required this.charityCreditsTotal,
    required this.generatedAt,
  });

  String get formattedDate =>
      '${generatedAt.month}/${generatedAt.day}/${generatedAt.year}';

  double get donationDollars => charityCreditsTotal * CharityService.creditsToDoller;

  String get receiptSummary =>
      'Charity Donation Receipt\n'
      '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n'
      'Bracket: $bracketName\n'
      'Charity: $charityName\n'
      '${charityGoal != null ? 'Goal: $charityGoal\n' : ''}'
      'Host: $hostName\n'
      'Date: $formattedDate\n'
      '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n'
      'Total Pot: $totalCreditsRaised credits (\$${(totalCreditsRaised * 0.10).toStringAsFixed(2)})\n'
      'BMB Platform Fee: $platformFeeTotal credits (\$${(platformFeeTotal * 0.10).toStringAsFixed(2)})\n'
      'Net Donation: $charityCreditsTotal credits (\$${donationDollars.toStringAsFixed(2)})\n'
      '\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\u2501\n'
      'Donated \$${donationDollars.toStringAsFixed(2)} to $charityName via Tremendous\n'
      '\nDisclaimer: ${CharityService.shortDisclaimer}';
}
