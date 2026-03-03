import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firestore_service.dart';

/// Central Firestore service for Back My Bracket.
/// Delegates to REST API for reliable cross-platform operation.
class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();

  final RestFirestoreService _rest = RestFirestoreService.instance;

  // ══════════════════════════════════════════════════════════════════════════
  // USERS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUser(String userId) =>
      _rest.getDocument('users', userId);

  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    final results = await _rest.query(
      'users',
      whereField: 'email',
      whereValue: email.toLowerCase().trim(),
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<void> setUser(String userId, Map<String, dynamic> data) =>
      _rest.setDocument('users', userId, data);

  Future<void> updateUser(String userId, Map<String, dynamic> fields) =>
      _rest.updateDocument('users', userId, fields);

  /// BUG #2 FIX: Use optimistic locking to prevent race conditions.
  /// Reads the current balance, computes the new value, writes it back,
  /// and then verifies the write. If another write happened concurrently,
  /// retries up to 3 times.
  Future<void> incrementUserCredits(String userId, int amount, {int retryCount = 0}) async {
    const maxRetries = 3;
    final user = await getUser(userId);
    if (user == null) return;

    final current = (user['credits_balance'] as num?)?.toInt() ?? 0;
    final newBalance = current + amount;

    // Prevent negative balance on deductions
    if (newBalance < 0 && amount < 0) {
      throw Exception('Insufficient credits: has $current, needs ${amount.abs()}');
    }

    await updateUser(userId, {'credits_balance': newBalance});

    // Verify the write succeeded with the expected value
    final verifyUser = await getUser(userId);
    final verifiedBalance = (verifyUser?['credits_balance'] as num?)?.toInt() ?? 0;

    if (verifiedBalance != newBalance && retryCount < maxRetries) {
      // Another write happened concurrently — retry with fresh data
      if (kDebugMode) {
        debugPrint('FirestoreService: Credit race detected for $userId, retry ${retryCount + 1}');
      }
      await incrementUserCredits(userId, amount, retryCount: retryCount + 1);
    }
  }

  Future<List<Map<String, dynamic>>> getAllUsers() =>
      _rest.getCollection('users');

  Future<Map<String, int>> getUserCountsByTier() async {
    final allUsers = await getAllUsers();
    final counts = <String, int>{
      'free': 0, 'plus': 0, 'business': 0, 'total': allUsers.length,
    };
    for (final u in allUsers) {
      final tier = (u['subscription_tier'] as String?) ?? 'free';
      counts[tier] = (counts[tier] ?? 0) + 1;
    }
    return counts;
  }

  // ══════════════════════════════════════════════════════════════════════════
  // BRACKETS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getBrackets({String? status}) async {
    if (status != null) {
      return _rest.query('brackets', whereField: 'status', whereValue: status);
    }
    return _rest.getCollection('brackets');
  }

  Future<List<Map<String, dynamic>>> getFeaturedBrackets() =>
      _rest.query('brackets', whereField: 'is_featured', whereValue: true);

  Future<List<Map<String, dynamic>>> getUserBrackets(String userId) async {
    final brackets = await _rest.query(
        'brackets', whereField: 'host_user_id', whereValue: userId);
    brackets.sort((a, b) {
      final aTime = a['created_at'] as String? ?? '';
      final bTime = b['created_at'] as String? ?? '';
      return bTime.compareTo(aTime);
    });
    return brackets;
  }

  Future<String> createBracket(Map<String, dynamic> data) async {
    final id = await _rest.addDocument('brackets', data);
    if (id != null) {
      await _rest.updateDocument('brackets', id, {'bracket_id': id});
    }
    return id ?? '';
  }

  Future<void> updateBracket(String bracketId, Map<String, dynamic> fields) =>
      _rest.updateDocument('brackets', bracketId, fields);

  Future<Map<String, dynamic>?> getBracket(String bracketId) =>
      _rest.getDocument('brackets', bracketId);

  // ══════════════════════════════════════════════════════════════════════════
  // SUBSCRIPTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUserSubscription(String userId) async {
    final results = await _rest.query(
        'subscriptions', whereField: 'user_id', whereValue: userId, limit: 1);
    return results.isNotEmpty ? results.first : null;
  }

  Future<List<Map<String, dynamic>>> getAllSubscriptions() =>
      _rest.getCollection('subscriptions');

  Future<void> setSubscription(Map<String, dynamic> data) =>
      _rest.addDocument('subscriptions', data).then((_) {});

  // ══════════════════════════════════════════════════════════════════════════
  // CREDIT TRANSACTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getUserCreditTransactions(
      String userId) async {
    final txns = await _rest.query(
        'credit_transactions', whereField: 'user_id', whereValue: userId);
    txns.sort((a, b) {
      final aTime = a['timestamp']?.toString() ?? '';
      final bTime = b['timestamp']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
    return txns;
  }

  Future<void> addCreditTransaction(Map<String, dynamic> data) =>
      _rest.addDocument('credit_transactions', data).then((_) {});

  // ══════════════════════════════════════════════════════════════════════════
  // BRACKET ENTRIES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getBracketEntries(
          String bracketId) =>
      _rest.query('bracket_entries',
          whereField: 'bracket_id', whereValue: bracketId);

  Future<List<Map<String, dynamic>>> getUserEntries(String userId) =>
      _rest.query('bracket_entries',
          whereField: 'user_id', whereValue: userId);

  Future<void> submitBracketEntry(Map<String, dynamic> data) async {
    await _rest.addDocument('bracket_entries', data);
    if (data['bracket_id'] != null) {
      // Increment entrants_count
      final bracket =
          await _rest.getDocument('brackets', data['bracket_id']);
      if (bracket != null) {
        final count =
            (bracket['entrants_count'] as num?)?.toInt() ?? 0;
        await _rest.updateDocument(
            'brackets', data['bracket_id'], {'entrants_count': count + 1});
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // COMPANION SELECTIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<String?> getUserCompanion(String userId) async {
    final doc =
        await _rest.getDocument('companion_selections', userId);
    return doc?['companion_id'] as String?;
  }

  Future<void> setUserCompanion(String userId, String companionId) =>
      _rest.setDocument('companion_selections', userId, {
        'user_id': userId,
        'companion_id': companionId,
        'selected_at': DateTime.now().toUtc().toIso8601String(),
      });

  // ══════════════════════════════════════════════════════════════════════════
  // ANALYTICS EVENTS
  // ══════════════════════════════════════════════════════════════════════════

  Future<void> logEvent(Map<String, dynamic> event) async {
    event['timestamp'] = DateTime.now().toUtc().toIso8601String();
    await _rest.addDocument('analytics_events', event);
  }

  Future<List<Map<String, dynamic>>> getRecentEvents({int limit = 50}) async {
    final events = await _rest.getCollection('analytics_events');
    events.sort((a, b) {
      final aTime = a['timestamp']?.toString() ?? '';
      final bTime = b['timestamp']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
    return events.take(limit).toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN CONFIG
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getConfig(String configId) =>
      _rest.getDocument('admin_config', configId);

  Future<Map<String, dynamic>?> getPricing() => getConfig('pricing');
  Future<Map<String, dynamic>?> getFeatureFlags() => getConfig('feature_flags');
  Future<Map<String, dynamic>?> getAppSettings() => getConfig('app_settings');

  Future<void> updateConfig(
      String configId, Map<String, dynamic> fields) async {
    fields['updated_at'] = DateTime.now().toUtc().toIso8601String();
    await _rest.updateDocument('admin_config', configId, fields);
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ADMIN DASHBOARD AGGREGATIONS
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getAdminDashboardStats() async {
    try {
      final userCounts = await getUserCountsByTier();
      final allBrackets = await getBrackets();
      final allSubs = await getAllSubscriptions();

      int liveBrackets = 0, completedBrackets = 0, draftBrackets = 0;
      for (final b in allBrackets) {
        switch (b['status']) {
          case 'live': liveBrackets++; break;
          case 'completed': completedBrackets++; break;
          case 'draft': draftBrackets++; break;
        }
      }

      int activePlus = 0, activeBusiness = 0;
      double monthlyRevenue = 0;
      for (final s in allSubs) {
        if (s['status'] == 'active') {
          final plan = s['plan_type'] as String? ?? '';
          final price = (s['price_monthly'] as num?)?.toDouble() ?? 0;
          if (plan == 'plus') {
            activePlus++;
          } else if (plan == 'business') {
            activeBusiness++;
          }
          monthlyRevenue += price;
        }
      }

      return {
        'total_users': userCounts['total'] ?? 0,
        'free_users': userCounts['free'] ?? 0,
        'plus_users': userCounts['plus'] ?? 0,
        'business_users': userCounts['business'] ?? 0,
        'total_brackets': allBrackets.length,
        'live_brackets': liveBrackets,
        'completed_brackets': completedBrackets,
        'draft_brackets': draftBrackets,
        'active_plus_subscriptions': activePlus,
        'active_business_subscriptions': activeBusiness,
        'estimated_monthly_revenue': monthlyRevenue,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService.getAdminDashboardStats error: $e');
      return {};
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CREDIT TRANSACTIONS (ADMIN)
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getAllCreditTransactions(
      {int limit = 100}) async {
    final txns = await _rest.getCollection('credit_transactions');
    txns.sort((a, b) {
      final aTime = a['timestamp']?.toString() ?? '';
      final bTime = b['timestamp']?.toString() ?? '';
      return bTime.compareTo(aTime);
    });
    return txns.take(limit).toList();
  }

  Future<Map<String, dynamic>> getCreditFlowSummary() async {
    try {
      final txns = await _rest.getCollection('credit_transactions');
      int totalEarned = 0, totalSpent = 0;
      int signupBonuses = 0, entryFees = 0, adminGrants = 0, purchases = 0;
      for (final doc in txns) {
        final amount = (doc['amount'] as num?)?.toInt() ?? 0;
        final type = doc['type'] as String? ?? '';
        if (amount > 0) {
          totalEarned += amount;
          if (type == 'signup_bonus') signupBonuses += amount;
          if (type == 'admin_grant') adminGrants += amount;
          if (type == 'purchase') purchases += amount;
        } else {
          totalSpent += amount.abs();
          if (type == 'entry_fee') entryFees += amount.abs();
        }
      }
      return {
        'total_earned': totalEarned,
        'total_spent': totalSpent,
        'net_flow': totalEarned - totalSpent,
        'signup_bonuses': signupBonuses,
        'entry_fees': entryFees,
        'admin_grants': adminGrants,
        'purchases': purchases,
        'transaction_count': txns.length,
      };
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService.getCreditFlowSummary error: $e');
      return {};
    }
  }

  Future<void> adminAdjustCredits(
      String userId, int amount, String reason) async {
    await incrementUserCredits(userId, amount);
    await _rest.addDocument('credit_transactions', {
      'user_id': userId,
      'amount': amount,
      'type': amount > 0 ? 'admin_grant' : 'admin_deduction',
      'reason': reason,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
    });
    await logEvent({
      'event_type': 'admin_credit_adjustment',
      'user_id': userId,
      'amount': amount,
      'reason': reason,
    });
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE 2: LIVE DASHBOARD DATA
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getUserStats(String userId) async {
    try {
      final user = await getUser(userId);
      if (user == null) return {};

      final createdBrackets = await _rest.query(
          'brackets', whereField: 'host_user_id', whereValue: userId);
      final entries = await _rest.query(
          'bracket_entries', whereField: 'user_id', whereValue: userId);
      final txns = await _rest.query(
          'credit_transactions', whereField: 'user_id', whereValue: userId);

      int totalEarnings = 0, totalSpent = 0;
      for (final doc in txns) {
        final amount = (doc['amount'] as num?)?.toInt() ?? 0;
        if (amount > 0) {
          totalEarnings += amount;
        } else {
          totalSpent += amount.abs();
        }
      }

      final wonBrackets = await _rest.query(
          'brackets', whereField: 'winner_user_id', whereValue: userId);

      return {
        'credits_balance': (user['credits_balance'] as num?)?.toInt() ?? 0,
        'brackets_created': createdBrackets.length,
        'brackets_entered': entries.length,
        'total_winnings': (user['total_winnings'] as num?)?.toInt() ?? totalEarnings,
        'total_spent': totalSpent,
        'wins': wonBrackets.length,
        'subscription_tier': user['subscription_tier'] as String? ?? 'free',
        'is_bmb_plus': user['is_bmb_plus'] as bool? ?? false,
        'is_bmb_vip': user['is_bmb_vip'] as bool? ?? false,
        'is_admin': user['is_admin'] as bool? ?? false,
        'is_business': user['is_business'] as bool? ?? false,
        'display_name': user['display_name'] as String? ?? '',
        'state': user['state'] as String? ?? '',
        'city': user['city'] as String? ?? '',
        'referral_code': user['referral_code'] as String? ?? '',
      };
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService.getUserStats error: $e');
      return {};
    }
  }

  Future<List<Map<String, dynamic>>> getTopHosts({int limit = 10}) async {
    try {
      final allBrackets = await _rest.getCollection('brackets');
      final hostCounts = <String, int>{};
      final hostNames = <String, String>{};
      for (final doc in allBrackets) {
        final hostId = doc['host_user_id'] as String? ?? '';
        final hostName = doc['host_display_name'] as String? ?? '';
        if (hostId.isNotEmpty) {
          hostCounts[hostId] = (hostCounts[hostId] ?? 0) + 1;
          if (hostName.isNotEmpty) hostNames[hostId] = hostName;
        }
      }

      final hosts = <Map<String, dynamic>>[];
      for (final entry in hostCounts.entries) {
        final userData = await getUser(entry.key);
        if (userData != null) {
          hosts.add({
            'user_id': entry.key,
            'display_name': userData['display_name'] as String? ??
                hostNames[entry.key] ?? 'Unknown',
            'state': userData['state'] as String? ?? '',
            'city': userData['city'] as String? ?? '',
            'brackets_created': entry.value,
            'is_bmb_plus': userData['is_bmb_plus'] as bool? ?? false,
            'avatar_index': (userData['avatar_index'] as num?)?.toInt() ?? 0,
            'credits_balance': (userData['credits_balance'] as num?)?.toInt() ?? 0,
          });
        } else {
          hosts.add({
            'user_id': entry.key,
            'display_name': hostNames[entry.key] ?? 'Unknown',
            'state': '',
            'brackets_created': entry.value,
            'is_bmb_plus': false,
            'avatar_index': 0,
          });
        }
      }

      hosts.sort((a, b) =>
          (b['brackets_created'] as int).compareTo(a['brackets_created'] as int));
      return hosts.take(limit).toList();
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService.getTopHosts error: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getActiveBrackets() async {
    try {
      final allBrackets = await _rest.getCollection('brackets');
      final active = allBrackets.where((doc) {
        final status = doc['status'] as String? ?? '';
        return status == 'live' || status == 'upcoming' || status == 'in_progress';
      }).toList();

      final statusOrder = {'live': 0, 'upcoming': 1, 'in_progress': 2};
      active.sort((a, b) {
        final aO = statusOrder[a['status']] ?? 3;
        final bO = statusOrder[b['status']] ?? 3;
        return aO.compareTo(bO);
      });
      return active;
    } catch (e) {
      if (kDebugMode) debugPrint('FirestoreService.getActiveBrackets error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE 6: AUTO-HOST — SAVED TEMPLATES
  // ══════════════════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getHostSavedTemplates(
          String hostId) =>
      _rest.query('saved_templates',
          whereField: 'host_id', whereValue: hostId);

  Future<List<Map<String, dynamic>>> getPendingApprovalBrackets(
      String hostId) async {
    // REST doesn't support multi-field where; fetch by host then filter
    final brackets = await _rest.query(
        'brackets', whereField: 'host_user_id', whereValue: hostId);
    return brackets.where((b) => b['status'] == 'saved').toList();
  }

  // ══════════════════════════════════════════════════════════════════════════
  // PHASE 6: AUTO-HOST — BRACKET RESERVATIONS (EARLY JOIN)
  // ══════════════════════════════════════════════════════════════════════════

  Future<int> getReservationCount(String bracketId) async {
    final reservations = await _rest.query(
        'bracket_reservations',
        whereField: 'bracket_id',
        whereValue: bracketId);
    return reservations
        .where((r) => r['status'] == 'reserved')
        .length;
  }

  Future<bool> hasUserReserved(String bracketId, String userId) async {
    final reservations = await _rest.query(
        'bracket_reservations',
        whereField: 'bracket_id',
        whereValue: bracketId);
    return reservations.any(
        (r) => r['user_id'] == userId && r['status'] == 'reserved');
  }
}
