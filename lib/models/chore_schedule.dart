/// A recurring (or one-off) schedule entry assigning a chore to a person.
class ChoreSchedule {
  final String id;
  final String choreId;
  final String personId;
  final List<int> days; // 1=Monday … 7=Sunday (ISO 8601)
  final bool recurring;

  const ChoreSchedule({
    required this.id,
    required this.choreId,
    required this.personId,
    required this.days,
    required this.recurring,
  });

  factory ChoreSchedule.fromJson(Map<String, dynamic> json, String docId) {
    return ChoreSchedule(
      id: docId,
      choreId: json['chore_id'] as String,
      personId: json['person_id'] as String,
      days: (json['days'] as List<dynamic>).cast<int>(),
      recurring: json['recurring'] as bool,
    );
  }

  Map<String, dynamic> toJson() => {
        'chore_id': choreId,
        'person_id': personId,
        'days': days,
        'recurring': recurring,
      };

  ChoreSchedule copyWith({
    String? id,
    String? choreId,
    String? personId,
    List<int>? days,
    bool? recurring,
  }) {
    return ChoreSchedule(
      id: id ?? this.id,
      choreId: choreId ?? this.choreId,
      personId: personId ?? this.personId,
      days: days ?? this.days,
      recurring: recurring ?? this.recurring,
    );
  }
}
