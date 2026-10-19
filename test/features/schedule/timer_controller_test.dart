import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chores/models/models.dart';
import 'package:chores/providers/providers.dart';
import 'package:chores/features/schedule/state/timer_controller.dart';

import '../../helpers.dart';

void main() {
  late FakeFirebaseFirestore db;
  late SharedPreferences prefs;
  late DateTime now;
  final containers = <ProviderContainer>[];

  setUp(() async {
    db = FakeFirebaseFirestore();
    SharedPreferences.setMockInitialValues({'household_id': hid});
    prefs = await SharedPreferences.getInstance();
    now = DateTime(2026, 10, 19, 10);
  });

  tearDown(() {
    for (final c in containers) {
      c.dispose();
    }
    containers.clear();
  });

  /// A device signed in as [memberId], sharing the same Firestore.
  TimerController controllerFor(String memberId) {
    final container = ProviderContainer(overrides: [
      firestoreProvider.overrideWithValue(db),
      sharedPrefsProvider.overrideWithValue(prefs),
      currentMemberIdProvider.overrideWithValue(memberId),
      clockProvider.overrideWithValue(() => now),
    ]);
    containers.add(container);
    return container.read(timerControllerProvider);
  }

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  Future<List<TimeLog>> logs() async {
    final snap = await db
        .collection('households/$hid/time_logs')
        .get();
    return snap.docs.map((d) => TimeLog.fromJson(d.data(), d.id)).toList();
  }

  Future<WeekItem?> item(ScheduleSlot s) async {
    final doc =
        await db.doc('households/$hid/week_items/${s.itemId}').get();
    return doc.exists ? WeekItem.fromJson(doc.data()!, doc.id) : null;
  }

  test('start opens a running session credited to me', () async {
    await controllerFor('ana').start(slot());

    final all = await logs();
    expect(all, hasLength(1));
    expect(all.single.personId, 'ana');
    expect(all.single.isRunning, isTrue);
    expect(await item(slot()), isNull, reason: 'item docs are lazy');
  });

  test('starting the same item twice is a no-op', () async {
    final ana = controllerFor('ana');
    await ana.start(slot());
    await ana.start(slot());
    expect(await logs(), hasLength(1));
  });

  test('one timer per person: starting another item closes the first',
      () async {
    final ana = controllerFor('ana');
    await ana.start(slot(day: 1));
    advance(300);
    await ana.start(slot(day: 2));

    final all = await logs();
    final first = all.firstWhere((l) => l.day == 1);
    final second = all.firstWhere((l) => l.day == 2);
    expect(first.isRunning, isFalse);
    expect(first.durationSeconds, 300);
    expect(second.isRunning, isTrue);
  });

  test('paused time is never counted', () async {
    final ana = controllerFor('ana');
    await ana.start(slot());
    advance(120);
    await ana.pause(slot());
    advance(3600); // long break
    await ana.start(slot());
    advance(60);
    await ana.complete(slot());

    final all = await logs();
    expect(all.every((l) => !l.isRunning), isTrue);
    expect(all.fold<int>(0, (s, l) => s + l.durationSeconds!), 180);

    final done = await item(slot());
    expect(done!.status, WeekItemStatus.done);
    expect(done.completedBy, 'ana');
  });

  test('two people can time the same item; totals add up', () async {
    final ana = controllerFor('ana');
    final bob = controllerFor('bob');
    await ana.start(slot());
    await bob.start(slot());
    advance(600);
    await bob.pause(slot());
    expect((await logs()).where((l) => l.isRunning).single.personId, 'ana',
        reason: "bob's pause must not stop ana's timer");

    advance(300);
    await ana.complete(slot());

    final all = await logs();
    final byPerson = {for (final l in all) l.personId: l.durationSeconds};
    expect(byPerson, {'ana': 900, 'bob': 600});
  });

  test('manual time is credited to the chosen doer and completes the item',
      () async {
    await controllerFor('ana').addManual(slot(), personId: 'bob', seconds: 1800);

    final log = (await logs()).single;
    expect(log.source, TimeLogSource.manual);
    expect(log.personId, 'bob');
    expect(log.durationSeconds, 1800);

    final done = await item(slot());
    expect(done!.isDone, isTrue);
    expect(done.completedBy, 'bob');
  });

  test('manual time must be positive', () async {
    expect(
      () => controllerFor('ana').addManual(slot(), personId: 'ana', seconds: 0),
      throwsArgumentError,
    );
  });

  test('reopen keeps logged time', () async {
    final ana = controllerFor('ana');
    await ana.addManual(slot(), personId: 'ana', seconds: 600);
    await ana.reopen(slot());

    expect((await item(slot()))!.status, WeekItemStatus.open);
    expect(await logs(), hasLength(1));
  });

  group('editing sessions', () {
    test('any member can change a closed session\'s duration', () async {
      final ana = controllerFor('ana');
      await ana.start(slot());
      advance(5 * 3600); // forgot to stop
      await ana.pause(slot());

      final log = (await logs()).single;
      await controllerFor('bob').editDuration(log, seconds: 45 * 60);

      expect((await logs()).single.durationSeconds, 45 * 60);
    });

    test('running sessions and non-positive minutes are rejected', () async {
      final ana = controllerFor('ana');
      await ana.start(slot());
      final running = (await logs()).single;
      expect(() => ana.editDuration(running, seconds: 600), throwsStateError);

      await ana.pause(slot());
      final closed = (await logs()).single;
      expect(() => ana.editDuration(closed, seconds: 0), throwsArgumentError);
    });

    test('deleting one of several sessions keeps the item done', () async {
      final ana = controllerFor('ana');
      await ana.addManual(slot(), personId: 'ana', seconds: 600);
      await ana.addManual(slot(), personId: 'bob', seconds: 1200);

      final mistake = (await logs()).firstWhere((l) => l.personId == 'bob');
      await controllerFor('bob').deleteLog(mistake);

      expect((await logs()).map((l) => l.personId), ['ana']);
      expect((await item(slot()))!.isDone, isTrue);
    });

    test('deleting the last session of a done item reopens it', () async {
      final ana = controllerFor('ana');
      await ana.addManual(slot(), personId: 'ana', seconds: 600);
      await ana.deleteLog((await logs()).single);

      expect(await logs(), isEmpty);
      expect((await item(slot()))!.status, WeekItemStatus.open);
    });

    test('deleting from an open item never creates an item doc', () async {
      final ana = controllerFor('ana');
      await ana.start(slot());
      await ana.deleteLog((await logs()).single);

      expect(await logs(), isEmpty);
      expect(await item(slot()), isNull);
    });
  });
}
