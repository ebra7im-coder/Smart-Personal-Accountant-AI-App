// Firebase layer: auth (Email, Google, Apple, Phone, Guest) + Firestore mirror.
//
// Everything is defensive: if Firebase isn't configured (missing
// google-services.json / placeholder options) the app keeps working fully
// offline — each call throws a local AuthError that the caller surfaces.

import 'package:cloud_firestore/cloud_firestore.dart' hide Transaction;
import 'package:firebase_auth/firebase_auth.dart' as fa;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../firebase_options.dart';
import '../models/budget.dart';
import '../models/transaction.dart';

/// Lightweight error type for local-only mode / auth failures.
class AuthServiceException implements Exception {
  const AuthServiceException(this.message, [this.code = 'unknown']);
  final String message;
  final String code;
}

abstract final class FirebaseService {
  static bool _ready = false;

  /// Initializes Firebase + sets English-safe settings for Firestore.
  static Future<void> ensureInitialized() async {
    if (_ready) return;
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseFirestore.instance.settings =
        const Settings(persistenceEnabled: true);
    _ready = true;
  }

  static bool get isReady => _ready;
}

abstract final class FirebaseAuthService {
  static fa.FirebaseAuth? _instanceOrNull() {
    try {
      return fa.FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  static fa.FirebaseAuth get _auth =>
      _instanceOrNull() ??
      (throw const AuthServiceException('Firebase غير مهيأ على هذا الجهاز'));

  static String? get currentUid {
    try {
      return _auth.currentUser?.uid;
    } catch (_) {
      return null;
    }
  }

  static bool get isSignedIn {
    try {
      return _auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Email ----------------

  static Future<fa.UserCredential> signInWithEmail(
      String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
          email: email, password: password);
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل تسجيل الدخول', e.code);
    }
  }

  static Future<fa.UserCredential> registerWithEmail(
      String email, String password) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل إنشاء الحساب', e.code);
    }
  }

  static Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل الإرسال', e.code);
    }
  }

  // ---------------- Google ----------------
  // Requires SHA-1/SHA-256 in Firebase console + google-services.json.

  static Future<fa.UserCredential> signInWithGoogle() async {
    try {
      final fa.GoogleAuthProvider google = fa.GoogleAuthProvider();
      return await _auth.signInWithProvider(google);
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل دخول جوجل', e.code);
    }
  }

  // ---------------- Apple (iOS / sign in with Apple) ----------------

  static Future<fa.UserCredential> signInWithApple() async {
    try {
      final fa.AppleAuthProvider apple = fa.AppleAuthProvider();
      return await _auth.signInWithProvider(apple);
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل دخول آبل', e.code);
    }
  }

  // ---------------- Guest ----------------

  static Future<fa.UserCredential> signInAsGuest() async {
    try {
      return await _auth.signInAnonymously();
    } on fa.FirebaseAuthException catch (e) {
      throw AuthServiceException(e.message ?? 'فشل الدخول كزائر', e.code);
    }
  }

  // ---------------- Phone (OTP) ----------------

  static Future<void> verifyPhone({
    required String phoneNumber,
    required void Function(String, int?) onCodeSent,
    required void Function(fa.PhoneAuthCredential) onAutoVerify,
    required void Function(fa.FirebaseAuthException) onFailed,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: timeout,
      verificationCompleted: onAutoVerify,
      verificationFailed: onFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String id) {},
    );
  }

  static Future<fa.UserCredential> verifySmsCode({
    required String verificationId,
    required String smsCode,
  }) {
    final fa.PhoneAuthCredential credential = fa.PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  // ---------------- Profile ----------------

  static Future<void> updateDisplayName(String name) async {
    final fa.User? user = _auth.currentUser;
    if (user != null) {
      await user.updateDisplayName(name);
      await user.reload();
    }
  }

  static Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {/* local-only mode */}
  }
}

abstract final class FirebaseFirestoreService {
  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _txCol(String uid) =>
      _db.collection('users').doc(uid).collection('transactions');

  static CollectionReference<Map<String, dynamic>> _budgetCol(String uid) =>
      _db.collection('users').doc(uid).collection('budgets');

  // ---------------- Transactions ----------------

  static Future<void> upsertTransaction(String uid, Transaction tx) async {
    await _txCol(uid).doc(tx.id).set(tx.toMap(), SetOptions(merge: true));
  }

  static Future<void> deleteTransaction(String uid, String id) =>
      _txCol(uid).doc(id).delete();

  static Future<List<Transaction>> fetchAllTransactions(String uid) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _txCol(uid).get();
    return snap.docs
        .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
            Transaction.fromMap(d.id, d.data()))
        .toList();
  }

  // ---------------- Budgets ----------------

  static Future<void> saveBudget(String uid, Budget budget) => _budgetCol(uid)
      .doc(budget.key)
      .set(budget.toMap(), SetOptions(merge: true));

  static Future<void> deleteBudget(String uid, String key) =>
      _budgetCol(uid).doc(key).delete();

  // ---------------- FCM token (for budget push notifications) ----------------

  static Future<void> saveFcmToken(String uid, String token) =>
      _db.collection('users').doc(uid).set(
        <String, dynamic>{'fcmToken': token},
        SetOptions(merge: true),
      );
}

abstract final class FcmService {
  /// Requests permissions and returns the FCM token (null when unavailable).
  static Future<String?> init() async {
    try {
      final FirebaseMessaging messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      return await messaging.getToken();
    } catch (_) {
      return null;
    }
  }

  static Future<void> onMessageHandler(
      void Function(RemoteMessage) handler) async {
    try {
      FirebaseMessaging.onMessage.listen(handler);
    } catch (_) {}
  }
}
