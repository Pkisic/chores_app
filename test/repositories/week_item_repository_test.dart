import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chores/models/models.dart';
import 'package:chores/repositories/repositories.dart';

import '../helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late WeekItemRepository repo;
  final t0 = DateTime(2026, 10, 19, 10);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = WeekItemRepository(firestore: db);
  });

  test('markDone lazily creates the item with a deterministic id', () async {
    await repo.markDone(hid, slot(), 'bob', t0);

    final items = await repo.streamWeek(hid, '2026-W43').first;
    final item = items.single;
    expect(item.id, '2026-W43_s1_1');
    expect(item.status, WeekItemStatus.done);
    expect(item.completedBy, 'bob');
    expect(item.completedAt!.toDate(), t0);
    expect(item.assignedPersonId, 'ana');
  });

  test('reopen sets status open and clears completion', () async {
    await repo.markDone(hid, slot(), 'bob', t0);
    await repo.reopen(hid, slot().itemId);

    final item = (await repo.streamWeek(hid, '2026-W43').first).single;
    expect(item.status, WeekItemStatus.open);
    expect(item.completedBy, isNull);
    expect(item.completedAt, isNull);
  });

  test('streamWeek only returns items of that week', () async {
    await repo.markDone(hid, slot(), 'ana', t0);
    await repo.markDone(hid, slot(weekId: '2026-W44'), 'ana', t0);

    final items = await repo.streamWeek(hid, '2026-W43').first;
    expect(items.map((i) => i.weekId), ['2026-W43']);
  });
}
