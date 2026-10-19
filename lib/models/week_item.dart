import 'package:cloud_firestore/cloud_firestore.dart';

/// Identifies one scheduled occurrence: a schedule entry on a given day of a
/// given ISO week. This is the unit that gets timed and completed.
class ScheduleSlot {
  final String weekId;
  final String scheduleId;
  final int day; // 1=Monday … 7=Sunday (ISO 8601)
  final String choreId;
  final String assignedPersonId;

  const ScheduleSlot({
    required this.weekId,
    required this.scheduleId,
    required this.day,
    required this.choreId,
    required this.assignedPersonId,
  });

  /// Deterministic id shared by the `week_items` doc and its time logs.
  String get itemId => '${weekId}_${scheduleId}_$day';
}

enum WeekItemStatus { open, done }

/// Persisted state of a [ScheduleSlot]. Created lazily, so a slot without a
/// doc is simply open with no time logged.
class WeekItem {
  final String id;
  final String weekId;
  final String scheduleId;
  final String choreId;
  final int day;
  final String assignedPersonId;
  final WeekItemStatus status;
  final Timestamp? completedAt;
  final String? completedBy;

  const WeekItem({
    required this.id,
    required this.weekId,
    required this.scheduleId,
    required this.choreId,
    required this.day,
    required this.assignedPersonId,
    this.status = WeekItemStatus.open,
    this.completedAt,
    this.completedBy,
  });

  factory WeekItem.fromSlot(ScheduleSlot slot) {
    return WeekItem(
      id: slot.itemId,
      weekId: slot.weekId,
      scheduleId: slot.scheduleId,
      choreId: slot.choreId,
      day: slot.day,
      assignedPersonId: slot.assignedPersonId,
    );
  }

  factory WeekItem.fromJson(Map<String, dynamic> json, String docId) {
    return WeekItem(
      id: docId,
      weekId: json['week_id'] as String,
      scheduleId: json['schedule_id'] as String,
      choreId: json['chore_id'] as String,
      day: json['day'] as int,
      assignedPersonId: json['assigned_person_id'] as String,
      status: WeekItemStatus.values.byName(json['status'] as String),
      completedAt: json['completed_at'] as Timestamp?,
      completedBy: json['completed_by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'week_id': weekId,
        'schedule_id': scheduleId,
        'chore_id': choreId,
        'day': day,
        'assigned_person_id': assignedPersonId,
        'status': status.name,
        'completed_at': completedAt,
        'completed_by': completedBy,
      };

  bool get isDone => status == WeekItemStatus.done;
}
