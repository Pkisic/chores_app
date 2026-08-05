import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a household that two people share.
class Household {
  final String id;
  final String inviteCode;
  final Timestamp createdAt;

  const Household({
    required this.id,
    required this.inviteCode,
    required this.createdAt,
  });

  factory Household.fromJson(Map<String, dynamic> json, String docId) {
    return Household(
      id: docId,
      inviteCode: json['invite_code'] as String,
      createdAt: json['created_at'] as Timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'invite_code': inviteCode,
        'created_at': createdAt,
      };
}
