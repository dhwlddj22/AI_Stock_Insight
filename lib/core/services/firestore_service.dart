import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _favoritesCol(String uid) =>
      _db.collection('users').doc(uid).collection('favorites');

  static Future<List<String>> fetchFavorites(String uid) async {
    final snapshot = await _favoritesCol(uid).get();
    return snapshot.docs.map((d) => d.id).toList();
  }

  static Future<void> addFavorite(String uid, String symbol) async {
    await _favoritesCol(uid).doc(symbol).set({'addedAt': FieldValue.serverTimestamp()});
  }

  static Future<void> removeFavorite(String uid, String symbol) async {
    await _favoritesCol(uid).doc(symbol).delete();
  }

  static Stream<List<String>> favoritesStream(String uid) {
    return _favoritesCol(uid).snapshots().map((snap) => snap.docs.map((d) => d.id).toList());
  }
}
