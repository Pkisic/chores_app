import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for schedule (chore ↔ person ↔ days) CRUD.
class ScheduleRepository {
  final FirebaseFirestore _db;

  ScheduleRepository({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _scheduleCol(String hid) =>
      _db.collection('households').doc(hid).collection('schedule');

  Stream<List<ChoreSchedule>> streamSchedules(String householdId) {
    return _scheduleCol(householdId).snapshots().map((snap) => snap.docs
        .map((d) => ChoreSchedule.fromJson(d.data(), d.id))
        .toList());
  }

  Future<ChoreSchedule> addSchedule(
      String householdId, ChoreSchedule schedule) async {
    final doc = _scheduleCol(householdId).doc();
    final created = schedule.copyWith(id: doc.id);
    await doc.set(created.toJson());
    return created;
  }

  Future<void> updateSchedule(
      String householdId, ChoreSchedule schedule) async {
    await _scheduleCol(householdId).doc(schedule.id).update(schedule.toJson());
  }

  Future<void> deleteSchedule(
      String householdId, String scheduleId) async {
    await _scheduleCol(householdId).doc(scheduleId).delete();
  }
}
