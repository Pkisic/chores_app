import 'package:chores/models/models.dart';

const hid = 'h1';

ScheduleSlot slot({
  String weekId = '2026-W43',
  String scheduleId = 's1',
  int day = 1,
  String choreId = 'c1',
  String assignedPersonId = 'ana',
}) {
  return ScheduleSlot(
    weekId: weekId,
    scheduleId: scheduleId,
    day: day,
    choreId: choreId,
    assignedPersonId: assignedPersonId,
  );
}
