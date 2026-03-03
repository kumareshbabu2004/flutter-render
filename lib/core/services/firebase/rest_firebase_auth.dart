import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Firebase Auth via REST API — works in any environment (iframe, sandbox, etc.)
/// without requiring the Firebase JS SDK.
class RestFirebaseAuth {
  RestFirebaseAuth._();
  static final RestFirebaseAuth instance = RestFirebaseAuth._();

  static const String _apiKey = 'AIzaSyCVIyREqZNFsa025kL0BrTAMsZtWssxK2k';
  static const String _authBaseUrl =
      'https://identitytoolkit.googleapis.com/v1';
  static const String _secureTokenUrl =
      'https://securetoken.googleapis.com/v1/token';

  /// Currently signed-in user info (null if not signed in).
  Map<String, dynamic>? _currentUser;
  String? _idToken;
  String? _refreshToken;
  String? _uid;

  /// Current user's UID.
  String? get uid => _uid;

  /// Current user's display name.
  String? get displayName => _currentUser?['displayName'] as String?;

  /// Current user's email.
  String? get email => _currentUser?['email'] as String?;

  /// Whether a user is currently signed in.
  bool get isSignedIn => _uid != null && _idToken != null;

  /// The current ID token (for Firestore REST calls).
  String? get idToken => _idToken;

  /// Sign in with email and password.
  /// Returns the Firebase user ID on success, throws on failure.
  Future<String> signIn({
    required String email,
    required String password,
  }) async {
    final url =
        '$_authBaseUrl/accounts:signInWithPassword?key=$_apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.toLowerCase().trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage = _mapRestError(
          error['error']?['message'] as String? ?? 'UNKNOWN_ERROR');
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _uid = data['localId'] as String?;
    _idToken = data['idToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;
    _currentUser = {
      'localId': _uid,
      'email': data['email'],
      'displayName': data['displayName'] ?? '',
      'idToken': _idToken,
    };

    if (kDebugMode) debugPrint('RestFirebaseAuth: Signed in as $_uid');
    return _uid!;
  }

  /// Create a new account with email and password.
  /// Returns the Firebase user ID on success, throws on failure.
  Future<String> signUp({
    required String email,
    required String password,
    String? displayName,
  }) async {
    final url = '$_authBaseUrl/accounts:signUp?key=$_apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.toLowerCase().trim(),
        'password': password,
        'returnSecureToken': true,
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage = _mapRestError(
          error['error']?['message'] as String? ?? 'UNKNOWN_ERROR');
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    _uid = data['localId'] as String?;
    _idToken = data['idToken'] as String?;
    _refreshToken = data['refreshToken'] as String?;

    // Update display name if provided
    if (displayName != null && displayName.isNotEmpty) {
      await _updateProfile(displayName: displayName);
    }

    _currentUser = {
      'localId': _uid,
      'email': data['email'],
      'displayName': displayName ?? '',
      'idToken': _idToken,
    };

    if (kDebugMode) debugPrint('RestFirebaseAuth: Signed up as $_uid');
    return _uid!;
  }

  /// Update user profile (display name).
  Future<void> _updateProfile({String? displayName}) async {
    if (_idToken == null) return;
    final url = '$_authBaseUrl/accounts:update?key=$_apiKey';
    await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'idToken': _idToken,
        if (displayName != null) 'displayName': displayName,
        'returnSecureToken': false,
      }),
    );
  }

  /// Sign out.
  void signOut() {
    _currentUser = null;
    _idToken = null;
    _refreshToken = null;
    _uid = null;
    if (kDebugMode) debugPrint('RestFirebaseAuth: Signed out');
  }

  /// Send password reset email.
  Future<void> sendPasswordResetEmail(String email) async {
    final url = '$_authBaseUrl/accounts:sendOobCode?key=$_apiKey';
    final response = await http.post(
      Uri.parse(url),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'requestType': 'PASSWORD_RESET',
        'email': email.toLowerCase().trim(),
      }),
    );

    if (response.statusCode != 200) {
      final error = jsonDecode(response.body);
      final errorMessage = _mapRestError(
          error['error']?['message'] as String? ?? 'UNKNOWN_ERROR');
      throw Exception(errorMessage);
    }
  }

  /// Refresh the ID token using the refresh token.
  Future<void> refreshIdToken() async {
    if (_refreshToken == null) return;
    final response = await http.post(
      Uri.parse('$_secureTokenUrl?key=$_apiKey'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: 'grant_type=refresh_token&refresh_token=$_refreshToken',
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _idToken = data['id_token'] as String?;
      _refreshToken = data['refresh_token'] as String?;
    }
  }

  /// Map Firebase REST API error codes to user-friendly messages.
  String _mapRestError(String errorCode) {
    switch (errorCode) {
      case 'EMAIL_NOT_FOUND':
        return 'No account found with this email address.';
      case 'INVALID_PASSWORD':
        return 'Incorrect password. Please try again.';
      case 'USER_DISABLED':
        return 'This account has been disabled. Contact support.';
      case 'EMAIL_EXISTS':
        return 'An account already exists with this email address.';
      case 'OPERATION_NOT_ALLOWED':
        return 'Email/password sign-in is not enabled.';
      case 'TOO_MANY_ATTEMPTS_TRY_LATER':
        return 'Too many attempts. Please wait and try again.';
      case 'WEAK_PASSWORD':
        return 'Password must be at least 6 characters.';
      case 'INVALID_EMAIL':
        return 'Please enter a valid email address.';
      case 'INVALID_LOGIN_CREDENTIALS':
        return 'Invalid email or password. Please try again.';
      default:
        return 'Authentication failed: $errorCode';
    }
  }
}
