import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chores/models/models.dart';
import 'package:chores/repositories/repositories.dart';

import '../helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late TimeLogRepository repo;
  final t0 = DateTime(2026, 10, 19, 10);

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = TimeLogRepository(firestore: db);
  });

  test('startSession creates a running timer log for the slot', () async {
    final log = await repo.startSession(hid, slot(), 'ana', t0);

    final running = await repo.getRunningLogs(hid, 'ana');
    expect(running, hasLength(1));
    final stored = running.single;
    expect(stored.id, log.id);
    expect(stored.itemId, '2026-W43_s1_1');
    expect(stored.weekId, '2026-W43');
    expect(stored.source, TimeLogSource.timer);
    expect(stored.isRunning, isTrue);
  });

  test('closeSession stores exact active duration', () async {
    final log = await repo.startSession(hid, slot(), 'ana', t0);
    await repo.closeSession(hid, log, t0.add(const Duration(minutes: 12)));

    expect(await repo.getRunningLogs(hid, 'ana'), isEmpty);
    final logs = await repo.streamWeekLogs(hid, '2026-W43').first;
    expect(logs.single.durationSeconds, 12 * 60);
    expect(logs.single.endedAt, isNotNull);
  });

  test('getRunningLogs only returns that person\'s open sessions', () async {
    await repo.startSession(hid, slot(), 'ana', t0);
    await repo.startSession(hid, slot(), 'bob', t0);
    final closed = await repo.startSession(hid, slot(day: 2), 'ana', t0);
    await repo.closeSession(hid, closed, t0);

    final running = await repo.getRunningLogs(hid, 'ana');
    expect(running.map((l) => l.personId), ['ana']);
    expect(running.single.day, 1);
  });

  test('logManual is created closed, not backdated', () async {
    await repo.logManual(hid, slot(), 'bob', 1800, t0);

    final log = (await repo.streamWeekLogs(hid, '2026-W43').first).single;
    expect(log.source, TimeLogSource.manual);
    expect(log.personId, 'bob');
    expect(log.durationSeconds, 1800);
    expect(log.startedAt.toDate(), t0);
    expect(log.endedAt!.toDate(), t0);
  });

  test('streamWeekLogs filters by week', () async {
    await repo.logManual(hid, slot(), 'ana', 60, t0);
    await repo.logManual(hid, slot(weekId: '2026-W44'), 'ana', 60, t0);

    final logs = await repo.streamWeekLogs(hid, '2026-W44').first;
    expect(logs.map((l) => l.weekId), ['2026-W44']);
  });

  test('writes join a batch and only land on commit', () async {
    final batch = db.batch();
    await repo.logManual(hid, slot(), 'ana', 60, t0, batch: batch);
    expect(await repo.streamWeekLogs(hid, '2026-W43').first, isEmpty);

    await batch.commit();
    expect(await repo.streamWeekLogs(hid, '2026-W43').first, hasLength(1));
  });

  test('getItemLogs, updateDuration and deleteLog', () async {
    final a = await repo.logManual(hid, slot(), 'ana', 60, t0);
    await repo.logManual(hid, slot(day: 2), 'ana', 60, t0);

    expect((await repo.getItemLogs(hid, slot().itemId)).map((l) => l.id),
        [a.id]);

    await repo.updateDuration(hid, a.id, 900);
    expect((await repo.getItemLogs(hid, slot().itemId)).single.durationSeconds,
        900);

    await repo.deleteLog(hid, a.id);
    expect(await repo.getItemLogs(hid, slot().itemId), isEmpty);
  });
}
