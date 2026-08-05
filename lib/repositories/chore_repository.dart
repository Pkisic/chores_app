import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for chore definitions CRUD.
class ChoreRepository {
  final FirebaseFirestore _db;

  ChoreRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _choresCol(String hid) =>
      _db.collection('households').doc(hid).collection('chores');

  // ── Stream all chores ──────────────────────────────────────
  Stream<List<Chore>> streamChores(String householdId) {
    return _choresCol(householdId).snapshots().map((snap) =>
        snap.docs.map((d) => Chore.fromJson(d.data(), d.id)).toList());
  }

  // ── CRUD ───────────────────────────────────────────────────
  Future<Chore> addChore(String householdId, Chore chore) async {
    final doc = _choresCol(householdId).doc();
    final created = chore.copyWith(id: doc.id);
    await doc.set(created.toJson());
    return created;
  }

  Future<void> updateChore(String householdId, Chore chore) async {
    await _choresCol(householdId).doc(chore.id).update(chore.toJson());
  }

  Future<void> deleteChore(String householdId, String choreId) async {
    await _choresCol(householdId).doc(choreId).delete();
  }
}
