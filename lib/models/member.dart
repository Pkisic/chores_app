import 'package:cloud_firestore/cloud_firestore.dart';

/// A member of a household.
class Member {
  final String id;
  final String displayName;
  final Timestamp joinedAt;

  const Member({
    required this.id,
    required this.displayName,
    required this.joinedAt,
  });

  factory Member.fromJson(Map<String, dynamic> json, String docId) {
    return Member(
      id: docId,
      displayName: json['display_name'] as String,
      joinedAt: json['joined_at'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'joined_at': joinedAt,
      };
}
