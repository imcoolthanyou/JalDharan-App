import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import '../config/api_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();

  factory AuthService() {
    return _instance;
  }

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: ['email', 'profile']);
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  static const String _jwtKey = 'jwt_token';
  static const String _userInfoKey = 'user_info';

  AuthService._internal();

  // Stream to listen to authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Get current user
  User? get currentUser => _firebaseAuth.currentUser;

  // Email and Password Sign Up
  Future<UserCredential> signUpWithEmail(String email, String password) async {
    try {
      final credential =
      await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      await _firestore
          .collection('users')
          .doc(credential.user!.uid)
          .set({
        'uid': credential.user!.uid,
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return credential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Email and Password Sign In
  Future<UserCredential> signInWithEmail(String email, String password) async {
    try {
      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Google Sign In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _debugPrintSignInInfo();

      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Obtain the auth details from the request
      if (googleUser == null) {
        if (kDebugMode) {
          print('User cancelled Google Sign In');
        }
        return null; // User cancelled the sign-in
      }

      if (kDebugMode) {
        print('Google user signed in: ${googleUser.email}');
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Validate credentials
      if (googleAuth.accessToken == null && googleAuth.idToken == null) {
        throw 'Failed to obtain authentication tokens from Google. '
            'Check your SHA1 certificate hash in Firebase Console.';
      }

      if (kDebugMode) {
        print(
          'Access Token: ${googleAuth.accessToken != null ? 'Present' : 'Null'}',
        );
        print('ID Token: ${googleAuth.idToken != null ? 'Present' : 'Null'}');
      }

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the credential
      final userCred = await _firebaseAuth.signInWithCredential(credential);
      await _firestore
          .collection('users')
          .doc(userCred.user!.uid)
          .set({
        'uid': userCred.user!.uid,
        'email': userCred.user!.email,
        'displayName': userCred.user!.displayName,
        'photoURL': userCred.user!.photoURL,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (kDebugMode) {
        print('Successfully signed in to Firebase: ${userCred.user?.email}');
      }

      return userCred;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('FirebaseAuthException: ${e.code} - ${e.message}');
      }
      throw _handleAuthException(e);
    } catch (e) {
      if (kDebugMode) {
        print('Google Sign In Error: $e');
      }

      // Check if it's a platform exception with specific error codes
      if (e.toString().contains('sign_in_failed')) {
        throw 'Google Sign In failed. This usually means:\n'
            '1. Your SHA1 certificate hash doesn\'t match Firebase Console\n'
            '2. Your package name doesn\'t match (com.litsquad.projects.jal_dharan)\n'
            '3. Run: ./gradlew signingReport to get your SHA1 hash\n'
            'Then update it in Firebase Console under Project Settings.';
      }

      throw 'Failed to sign in with Google: $e';
    }
  }

  // Apple Sign In (iOS specific, available on iOS 13+)
  Future<UserCredential?> signInWithApple() async {
    try {
      // Only available on iOS
      if (!Platform.isIOS) {
        throw 'Apple Sign-In is only available on iOS';
      }

      // Generate nonce for security
      final rawNonce = _generateNonce();
      final bytes = utf8.encode(rawNonce);
      final digest = sha256.convert(bytes);
      final hashNonce = base64Url.encode(digest.bytes).replaceAll('=', '');

      // Get Apple ID credential from native iOS
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [],
        nonce: hashNonce,
      );

      // Create Firebase credential with the Apple credential
      final oauthCredential = OAuthProvider(
        'apple.com',
      ).credential(idToken: appleCredential.identityToken, rawNonce: rawNonce);

      // Sign in to Firebase with the credential
      return await _firebaseAuth.signInWithCredential(oauthCredential);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'Failed to sign in with Apple: $e';
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Update User Profile
  Future<void> updateUserProfile({
    String? displayName,
    String? photoURL,
  }) async {
    try {
      if (displayName != null) {
        await _firebaseAuth.currentUser?.updateDisplayName(displayName);
      }
      if (photoURL != null) {
        await _firebaseAuth.currentUser?.updatePhotoURL(photoURL);
      }
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // ── Backend JWT methods ──────────────────────────────────────────────────

  /// Sign in with Google AND exchange the Google ID token for a backend JWT
  /// Returns true if this is a new user (first sign-in)
  Future<bool> signInWithGoogleAndBackend() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) throw Exception('Sign-in cancelled');

    final googleAuth = await googleUser.authentication;
    final idToken = googleAuth.idToken;
    if (idToken == null) throw Exception('Failed to get Google ID token');

    // Sign into Firebase and detect new vs returning user
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: idToken,
    );
    final userCred = await _firebaseAuth.signInWithCredential(credential);
    final isNewUser = userCred.additionalUserInfo?.isNewUser ?? false;

    // Exchange with our backend (non-fatal if backend is down)
    try {
      final response = await http
          .post(
            Uri.parse(ApiConfig.authGoogleEndpoint),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'google_token': idToken}),
          )
          .timeout(ApiConfig.requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final jwt = data['access_token'] as String;
        await _secureStorage.write(key: _jwtKey, value: jwt);
        final userInfo = jsonEncode({
          'email': googleUser.email,
          'displayName': googleUser.displayName,
          'photoUrl': googleUser.photoUrl,
        });
        await _secureStorage.write(key: _userInfoKey, value: userInfo);
      } else {
        if (kDebugMode) print('Backend auth failed: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Backend auth error (non-fatal): $e');
    }

    return isNewUser;
  }

  /// Get the stored JWT token
  Future<String?> getToken() => _secureStorage.read(key: _jwtKey);

  /// Returns true if a JWT exists in secure storage
  Future<bool> isSignedInToBackend() async {
    final token = await _secureStorage.read(key: _jwtKey);
    return token != null && token.isNotEmpty;
  }

  /// Returns auth headers for backend API calls
  Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Get stored user info
  Future<Map<String, dynamic>?> getUserInfo() async {
    final raw = await _secureStorage.read(key: _userInfoKey);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
      await _secureStorage.delete(key: _jwtKey);
      await _secureStorage.delete(key: _userInfoKey);

      // Note: Apple Sign-In doesn't have a sign-out method,
      // the session is managed by iOS
    } catch (e) {
      throw 'Failed to sign out: $e';
    }
  }

  // Delete Account
  Future<void> deleteAccount() async {
    try {
      await _firebaseAuth.currentUser?.delete();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Verify Email
  Future<void> sendEmailVerification() async {
    try {
      await _firebaseAuth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    }
  }

  // Check if email is verified
  bool isEmailVerified() {
    return _firebaseAuth.currentUser?.emailVerified ?? false;
  }

  // Debug: Print configuration info for troubleshooting
  void _debugPrintSignInInfo() {
    if (kDebugMode) {
      print('=== Google Sign In Debug Info ===');
      print('Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}');
      print('Is signed in: ${_googleSignIn.currentUser != null}');
      print('Current account: ${_googleSignIn.currentUser?.email ?? 'None'}');
      print('Firebase user: ${_firebaseAuth.currentUser?.email ?? 'None'}');
      print('================================');
    }
  }

  // Helper method to handle Firebase Auth Exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'invalid-email':
        return 'The email address is not valid.';
      case 'operation-not-allowed':
        return 'Operation not allowed. Please contact support.';
      case 'user-disabled':
        return 'The user account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'The password is incorrect.';
      case 'invalid-credential':
        return 'The credentials provided are invalid.';
      case 'too-many-requests':
        return 'Too many failed login attempts. Please try again later.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'credential-already-in-use':
        return 'This credential is already in use by another account.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  // Generate Nonce for Apple Sign-In
  String _generateNonce() {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    final values = List<int>.generate(
      32,
      (i) => charset.codeUnitAt(random.nextInt(charset.length)),
    );
    return String.fromCharCodes(values);
  }
}
