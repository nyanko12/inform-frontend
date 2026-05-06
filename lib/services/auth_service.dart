import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn? _googleSignIn = kIsWeb ? null : GoogleSignIn();

  Stream<User?> get authStateChanges => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<String?> getIdToken() async {
    return await _auth.currentUser?.getIdToken();
  }

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createWithEmail(String email, String password) async {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential?> signInWithGoogle() async {
    if (kIsWeb) {
      final provider = GoogleAuthProvider();
      try {
        // まずpopupを試みる（PC・モバイル新タブどちらも対応）
        return await _auth.signInWithPopup(provider);
      } on FirebaseAuthException catch (e) {
        // ポップアップがブロックされた場合のみリダイレクトにフォールバック
        if (e.code == 'popup-blocked' || e.code == 'popup-closed-by-user') {
          await _auth.signInWithRedirect(provider);
          return null;
        }
        rethrow;
      }
    }

    if (_googleSignIn == null) return null;
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;
    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
  }

  // リダイレクト後の結果を取得
  Future<UserCredential?> getRedirectResult() async {
    if (!kIsWeb) return null;
    try {
      final result = await _auth
          .getRedirectResult()
          .timeout(const Duration(seconds: 5));
      return result.user != null ? result : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _googleSignIn?.signOut();
    await _auth.signOut();
  }
}
