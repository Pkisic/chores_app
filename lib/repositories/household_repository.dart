import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for household-level Firestore operations.
class HouseholdRepository {
  final FirebaseFirestore _db;

  HouseholdRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  // ── References ──────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> get _households =>
      _db.collection('households');

  DocumentReference<Map<String, dynamic>> _householdDoc(String id) =>
      _households.doc(id);

  // ── Create household ───────────────────────────────────────
  Future<Household> createHousehold() async {
    final code = _generateInviteCode();
    final doc = _households.doc();
    final household = Household(
      id: doc.id,
      inviteCode: code,
      createdAt: Timestamp.now(),
    );
    await doc.set(household.toJson());
    return household;
  }

  // ── Join household by invite code ──────────────────────────
  Future<Household?> findByInviteCode(String code) async {
    final snap = await _households
        .where('invite_code', isEqualTo: code.toUpperCase())
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return Household.fromJson(doc.data(), doc.id);
  }

  // ── Stream a household ─────────────────────────────────────
  Stream<Household?> streamHousehold(String householdId) {
    return _householdDoc(householdId).snapshots().map((snap) {
      if (!snap.exists) return null;
      return Household.fromJson(snap.data()!, snap.id);
    });
  }

  // ── Members ────────────────────────────────────────────────
  CollectionReference<Map<String, dynamic>> _membersCol(String hid) =>
      _householdDoc(hid).collection('members');

  Future<void> addMember(String householdId, Member member) async {
    await _membersCol(householdId).doc(member.id).set(member.toJson());
  }

  Stream<List<Member>> streamMembers(String householdId) {
    return _membersCol(householdId).snapshots().map((snap) =>
        snap.docs.map((d) => Member.fromJson(d.data(), d.id)).toList());
  }

  // ── Helpers ────────────────────────────────────────────────
  String _generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rng = Random.secure();
    return List.generate(6, (_) => chars[rng.nextInt(chars.length)]).join();
  }
}
