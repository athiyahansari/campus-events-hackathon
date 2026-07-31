import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, organizer }

UserRole userRoleFromString(String value) {
  return value == 'organizer' ? UserRole.organizer : UserRole.student;
}

String userRoleToString(UserRole role) {
  return role == UserRole.organizer ? 'organizer' : 'student';
}

class UserModel {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? club;
  final List<String> interests;
  final DateTime? createdAt;
  final DateTime? lastActiveAt;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.club,
    required this.createdAt,
    this.interests = const [],
    this.lastActiveAt,
  });

  factory UserModel.fromMap(String uid, Map<String, dynamic> map) {
    return UserModel(
      uid: uid,
      name: map['name'] as String? ?? '',
      email: map['email'] as String? ?? '',
      role: userRoleFromString(map['role'] as String? ?? 'student'),
      club: map['club'] as String?,
      interests: List<String>.from(map['interests'] as List? ?? []),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'role': userRoleToString(role),
      'club': club,
      'interests': interests,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'lastActiveAt': lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
    };
  }

  bool get isOrganizer => role == UserRole.organizer;
}
