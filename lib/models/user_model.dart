import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, organizer, admin }

UserRole userRoleFromString(String value) {
  switch (value) {
    case 'organizer':
      return UserRole.organizer;
    case 'admin':
      return UserRole.admin;
    default:
      return UserRole.student;
  }
}

String userRoleToString(UserRole role) {
  switch (role) {
    case UserRole.organizer:
      return 'organizer';
    case UserRole.admin:
      return 'admin';
    case UserRole.student:
      return 'student';
  }
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
  final int? age;
  final String? batch;
  final String? staffId;
  final bool organizerApproved;

  UserModel({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.club,
    required this.createdAt,
    this.interests = const [],
    this.lastActiveAt,
    this.age,
    this.batch,
    this.staffId,
    this.organizerApproved = false,
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
      age: map['age'] as int?,
      batch: map['batch'] as String?,
      staffId: map['staffId'] as String?,
      organizerApproved: map['organizerApproved'] as bool? ?? false,
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
      'age': age,
      'batch': batch,
      'staffId': staffId,
      'organizerApproved': organizerApproved,
    };
  }

  bool get isOrganizer => role == UserRole.organizer;
  bool get isAdmin => role == UserRole.admin;
}
