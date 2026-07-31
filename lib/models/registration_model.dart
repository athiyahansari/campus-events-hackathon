import 'package:cloud_firestore/cloud_firestore.dart';

class RegistrationModel {
  final String id;
  final String eventId;
  final String userId;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final DateTime? registeredAt;
  final bool reminderSent;

  RegistrationModel({
    required this.id,
    required this.eventId,
    required this.userId,
    required this.checkedIn,
    required this.checkedInAt,
    required this.registeredAt,
    this.reminderSent = false,
  });

  factory RegistrationModel.fromMap(String id, Map<String, dynamic> map) {
    return RegistrationModel(
      id: id,
      eventId: map['eventId'] as String? ?? '',
      userId: map['userId'] as String? ?? '',
      checkedIn: map['checkedIn'] as bool? ?? false,
      checkedInAt: (map['checkedInAt'] as Timestamp?)?.toDate(),
      registeredAt: (map['registeredAt'] as Timestamp?)?.toDate(),
      reminderSent: map['reminderSent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'userId': userId,
      'checkedIn': checkedIn,
      'checkedInAt': checkedInAt != null ? Timestamp.fromDate(checkedInAt!) : null,
      'registeredAt': registeredAt != null ? Timestamp.fromDate(registeredAt!) : FieldValue.serverTimestamp(),
      'reminderSent': reminderSent,
    };
  }
}
