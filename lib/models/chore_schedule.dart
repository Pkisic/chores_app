/// A schedule entry assigning a chore to a person on some weekdays.
///
/// Recurring entries apply to every week (`weekId == null`); one-off entries
/// apply only to the ISO week in [weekId].
class ChoreSchedule {
  final String id;
  final String choreId;
  final String personId;
  final List<int> days; // 1=Monday … 7=Sunday (ISO 8601)
  final bool recurring;
  final String? weekId; // set only for one-off entries

  const ChoreSchedule({
    required this.id,
    required this.choreId,
    required this.personId,
    required this.days,
    required this.recurring,
    this.weekId,
  });

  factory ChoreSchedule.fromJson(Map<String, dynamic> json, String docId) {
    return ChoreSchedule(
      id: docId,
      choreId: json['chore_id'] as String,
      personId: json['person_id'] as String,
      days: (json['days'] as List<dynamic>).cast<int>(),
      recurring: json['recurring'] as bool,
      weekId: json['week_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'chore_id': choreId,
        'person_id': personId,
        'days': days,
        'recurring': recurring,
        'week_id': recurring ? null : weekId,
      };

  /// Whether this entry shows up in the given ISO week.
  bool appliesTo(String weekId) => recurring || this.weekId == weekId;

  ChoreSchedule copyWith({
    String? id,
    String? choreId,
    String? personId,
    List<int>? days,
    bool? recurring,
    String? weekId,
  }) {
    return ChoreSchedule(
      id: id ?? this.id,
      choreId: choreId ?? this.choreId,
      personId: personId ?? this.personId,
      days: days ?? this.days,
      recurring: recurring ?? this.recurring,
      weekId: weekId ?? this.weekId,
    );
  }
}
