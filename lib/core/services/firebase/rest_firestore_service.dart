import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:bmb_mobile/core/services/firebase/rest_firebase_auth.dart';

/// Firestore REST API client — works in any environment without Firebase JS SDK.
class RestFirestoreService {
  RestFirestoreService._();
  static final RestFirestoreService instance = RestFirestoreService._();

  static const String _projectId = 'back-my-bracket-41250';
  static const String _baseUrl =
      'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents';

  RestFirebaseAuth get _auth => RestFirebaseAuth.instance;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_auth.idToken != null) 'Authorization': 'Bearer ${_auth.idToken}',
  };

  // ══════════════════════════════════════════════════════════════════════════
  // GENERIC OPERATIONS
  // ══════════════════════════════════════════════════════════════════════════

  /// Get a single document.
  Future<Map<String, dynamic>?> getDocument(
      String collection, String docId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$collection/$docId'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        return _parseDocument(jsonDecode(response.body));
      }
      if (response.statusCode == 404) return null;
      if (response.statusCode == 401 || response.statusCode == 403) {
        // Token might be expired, try refreshing
        await _auth.refreshIdToken();
        final retryResponse = await http.get(
          Uri.parse('$_baseUrl/$collection/$docId'),
          headers: _headers,
        );
        if (retryResponse.statusCode == 200) {
          return _parseDocument(jsonDecode(retryResponse.body));
        }
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.getDocument error: $e');
      return null;
    }
  }

  /// Get all documents in a collection.
  Future<List<Map<String, dynamic>>> getCollection(String collection) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/$collection'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final documents = data['documents'] as List<dynamic>? ?? [];
        return documents
            .map((doc) => _parseDocument(doc as Map<String, dynamic>))
            .where((doc) => doc != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.getCollection error: $e');
      return [];
    }
  }

  /// BUG #7 FIX: Generic helper that retries once on 401/403 with token refresh.
  Future<http.Response> _authenticatedRequest(
    Future<http.Response> Function() request,
  ) async {
    final response = await request();
    if (response.statusCode == 401 || response.statusCode == 403) {
      // Token expired — refresh and retry once
      await _auth.refreshIdToken();
      return await request();
    }
    return response;
  }

  /// Set (create or overwrite) a document.
  Future<void> setDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      final fields = _toFirestoreFields(data);
      await _authenticatedRequest(() => http.patch(
        Uri.parse('$_baseUrl/$collection/$docId'),
        headers: _headers,
        body: jsonEncode({'fields': fields}),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.setDocument error: $e');
    }
  }

  /// Update specific fields on a document.
  Future<void> updateDocument(
      String collection, String docId, Map<String, dynamic> data) async {
    try {
      final fields = _toFirestoreFields(data);
      final updateMask = data.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
      await _authenticatedRequest(() => http.patch(
        Uri.parse('$_baseUrl/$collection/$docId?$updateMask'),
        headers: _headers,
        body: jsonEncode({'fields': fields}),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.updateDocument error: $e');
    }
  }

  /// Add a document to a collection (auto-generated ID).
  Future<String?> addDocument(
      String collection, Map<String, dynamic> data) async {
    try {
      final fields = _toFirestoreFields(data);
      final response = await _authenticatedRequest(() => http.post(
        Uri.parse('$_baseUrl/$collection'),
        headers: _headers,
        body: jsonEncode({'fields': fields}),
      ));
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body) as Map<String, dynamic>;
        final name = result['name'] as String? ?? '';
        return name.split('/').last;
      }
      return null;
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.addDocument error: $e');
      return null;
    }
  }

  /// Query a collection with a simple where clause.
  Future<List<Map<String, dynamic>>> query(
    String collection, {
    String? whereField,
    dynamic whereValue,
    int? limit,
  }) async {
    try {
      final structuredQuery = <String, dynamic>{
        'from': [
          {'collectionId': collection}
        ],
      };

      if (whereField != null && whereValue != null) {
        structuredQuery['where'] = {
          'fieldFilter': {
            'field': {'fieldPath': whereField},
            'op': 'EQUAL',
            'value': _toFirestoreValue(whereValue),
          }
        };
      }

      if (limit != null) {
        structuredQuery['limit'] = limit;
      }

      final response = await _authenticatedRequest(() => http.post(
        Uri.parse(
            'https://firestore.googleapis.com/v1/projects/$_projectId/databases/(default)/documents:runQuery'),
        headers: _headers,
        body: jsonEncode({'structuredQuery': structuredQuery}),
      ));

      if (response.statusCode == 200) {
        final results = jsonDecode(response.body) as List<dynamic>;
        return results
            .where((r) =>
                r is Map<String, dynamic> && r.containsKey('document'))
            .map((r) =>
                _parseDocument(r['document'] as Map<String, dynamic>))
            .where((doc) => doc != null)
            .cast<Map<String, dynamic>>()
            .toList();
      }
      return [];
    } catch (e) {
      if (kDebugMode) debugPrint('RestFirestore.query error: $e');
      return [];
    }
  }

  // ══════════════════════════════════════════════════════════════════════════
  // CONVENIENCE METHODS (compatible with existing FirestoreService API)
  // ══════════════════════════════════════════════════════════════════════════

  Future<Map<String, dynamic>?> getUser(String userId) =>
      getDocument('users', userId);

  Future<void> setUser(String userId, Map<String, dynamic> data) =>
      setDocument('users', userId, data);

  Future<void> updateUser(String userId, Map<String, dynamic> fields) =>
      updateDocument('users', userId, fields);

  Future<List<Map<String, dynamic>>> getAllUsers() => getCollection('users');

  Future<List<Map<String, dynamic>>> getBrackets({String? status}) async {
    if (status != null) {
      return query('brackets', whereField: 'status', whereValue: status);
    }
    return getCollection('brackets');
  }

  Future<void> logEvent(Map<String, dynamic> event) async {
    event['timestamp'] = DateTime.now().toUtc().toIso8601String();
    await addDocument('analytics_events', event);
  }

  Future<void> addCreditTransaction(Map<String, dynamic> data) =>
      addDocument('credit_transactions', data).then((_) {});

  // ══════════════════════════════════════════════════════════════════════════
  // FIRESTORE VALUE CONVERSION
  // ══════════════════════════════════════════════════════════════════════════

  /// Parse a Firestore REST document into a flat Dart map.
  Map<String, dynamic>? _parseDocument(Map<String, dynamic> doc) {
    final fields = doc['fields'] as Map<String, dynamic>?;
    if (fields == null) return null;

    final result = <String, dynamic>{};
    final name = doc['name'] as String? ?? '';
    result['doc_id'] = name.split('/').last;

    for (final entry in fields.entries) {
      result[entry.key] = _fromFirestoreValue(entry.value as Map<String, dynamic>);
    }
    return result;
  }

  /// Convert a Firestore value object to a Dart value.
  dynamic _fromFirestoreValue(Map<String, dynamic> value) {
    if (value.containsKey('stringValue')) return value['stringValue'];
    if (value.containsKey('integerValue')) {
      return int.tryParse(value['integerValue'].toString()) ?? 0;
    }
    if (value.containsKey('doubleValue')) return value['doubleValue'];
    if (value.containsKey('booleanValue')) return value['booleanValue'];
    if (value.containsKey('timestampValue')) return value['timestampValue'];
    if (value.containsKey('nullValue')) return null;
    if (value.containsKey('arrayValue')) {
      final values = value['arrayValue']['values'] as List<dynamic>? ?? [];
      return values
          .map((v) => _fromFirestoreValue(v as Map<String, dynamic>))
          .toList();
    }
    if (value.containsKey('mapValue')) {
      final fields =
          value['mapValue']['fields'] as Map<String, dynamic>? ?? {};
      final result = <String, dynamic>{};
      for (final entry in fields.entries) {
        result[entry.key] =
            _fromFirestoreValue(entry.value as Map<String, dynamic>);
      }
      return result;
    }
    if (value.containsKey('referenceValue')) return value['referenceValue'];
    if (value.containsKey('geoPointValue')) return value['geoPointValue'];
    if (value.containsKey('bytesValue')) return value['bytesValue'];
    return null;
  }

  /// Convert a Dart map to Firestore fields format.
  Map<String, dynamic> _toFirestoreFields(Map<String, dynamic> data) {
    final fields = <String, dynamic>{};
    for (final entry in data.entries) {
      fields[entry.key] = _toFirestoreValue(entry.value);
    }
    return fields;
  }

  /// Convert a Dart value to a Firestore value object.
  Map<String, dynamic> _toFirestoreValue(dynamic value) {
    if (value == null) return {'nullValue': null};
    if (value is String) return {'stringValue': value};
    if (value is int) return {'integerValue': value.toString()};
    if (value is double) return {'doubleValue': value};
    if (value is bool) return {'booleanValue': value};
    if (value is DateTime) {
      return {'timestampValue': value.toUtc().toIso8601String()};
    }
    if (value is List) {
      return {
        'arrayValue': {
          'values': value.map((v) => _toFirestoreValue(v)).toList()
        }
      };
    }
    if (value is Map) {
      final fields = <String, dynamic>{};
      for (final entry in value.entries) {
        fields[entry.key.toString()] = _toFirestoreValue(entry.value);
      }
      return {
        'mapValue': {'fields': fields}
      };
    }
    return {'stringValue': value.toString()};
  }
}
