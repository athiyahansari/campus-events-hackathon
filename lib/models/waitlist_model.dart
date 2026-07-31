import 'package:cloud_firestore/cloud_firestore.dart';

class WaitlistModel {
  final String id;
  final String eventId;
  final String userId;
  final DateTime? joinedAt;

  WaitlistModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.joinedAt,
  });

  factory WaitlistModel.fromMap(String id, Map<String, dynamic> map) {
    return WaitlistModel(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      joinedAt: (map['joinedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'joinedAt': joinedAt != null ? Timestamp.fromDate(joinedAt!) : FieldValue.serverTimestamp(),
    };
  }
}
