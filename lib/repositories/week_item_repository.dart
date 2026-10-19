import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chores/models/models.dart';

/// Repository for per-week item state (open / done).
///
/// Docs are created lazily with a deterministic id ([ScheduleSlot.itemId]),
/// so writes are merge-upserts and a missing doc means "open".
class WeekItemRepository {
  final FirebaseFirestore _db;

  WeekItemRepository({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _itemsCol(String hid) =>
      _db.collection('households').doc(hid).collection('week_items');

  // ── Stream all item states of one week ─────────────────────
  Stream<List<WeekItem>> streamWeek(String householdId, String weekId) {
    return _itemsCol(householdId)
        .where('week_id', isEqualTo: weekId)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => WeekItem.fromJson(d.data(), d.id)).toList(),
        );
  }

  // ── Mark done ──────────────────────────────────────────────
  Future<void> markDone(
    String householdId,
    ScheduleSlot slot,
    String completedBy,
    DateTime now, {
    WriteBatch? batch,
  }) async {
    final data = {
      ...WeekItem.fromSlot(slot).toJson(),
      'status': WeekItemStatus.done.name,
      'completed_at': Timestamp.fromDate(now),
      'completed_by': completedBy,
    };
    await _upsert(householdId, slot, data, batch);
  }

  // ── Get one item (null when never touched) ─────────────────
  Future<WeekItem?> getItem(String householdId, String itemId) async {
    final doc = await _itemsCol(householdId).doc(itemId).get();
    return doc.exists ? WeekItem.fromJson(doc.data()!, doc.id) : null;
  }

  // ── Reopen (logged time is kept) ───────────────────────────
  // Only done items can be reopened, so the doc always exists here.
  Future<void> reopen(
    String householdId,
    String itemId, {
    WriteBatch? batch,
  }) async {
    final doc = _itemsCol(householdId).doc(itemId);
    final data = {
      'status': WeekItemStatus.open.name,
      'completed_at': null,
      'completed_by': null,
    };
    if (batch != null) {
      batch.update(doc, data);
    } else {
      await doc.update(data);
    }
  }

  Future<void> _upsert(
    String householdId,
    ScheduleSlot slot,
    Map<String, dynamic> data,
    WriteBatch? batch,
  ) async {
    final doc = _itemsCol(householdId).doc(slot.itemId);
    final options = SetOptions(merge: true);
    if (batch != null) {
      batch.set(doc, data, options);
    } else {
      await doc.set(data, options);
    }
  }
}
