import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<UserCredential> signInAnonymously() {
    return _auth.signInAnonymously();
  }

  static Future<void> signOut() => _auth.signOut();
}
