/// A single chore definition (template, not an instance).
class Chore {
  final String id;
  final String name;
  final String color; // hex, e.g. '#FF6B6B'
  final String icon; // Material icon name key
  final int durationEstimate; // minutes

  const Chore({
    required this.id,
    required this.name,
    required this.color,
    required this.icon,
    required this.durationEstimate,
  });

  factory Chore.fromJson(Map<String, dynamic> json, String docId) {
    return Chore(
      id: docId,
      name: json['name'] as String,
      color: json['color'] as String,
      icon: json['icon'] as String,
      durationEstimate: json['duration_estimate'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'color': color,
        'icon': icon,
        'duration_estimate': durationEstimate,
      };

  Chore copyWith({
    String? id,
    String? name,
    String? color,
    String? icon,
    int? durationEstimate,
  }) {
    return Chore(
      id: id ?? this.id,
      name: name ?? this.name,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      durationEstimate: durationEstimate ?? this.durationEstimate,
    );
  }
}
