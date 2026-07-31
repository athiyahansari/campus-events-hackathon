import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { draft, published, concluded, archived }

EventStatus eventStatusFromString(String value) {
  switch (value) {
    case 'published':
      return EventStatus.published;
    case 'concluded':
      return EventStatus.concluded;
    case 'archived':
      return EventStatus.archived;
    case 'draft':
    default:
      return EventStatus.draft;
  }
}

String eventStatusToString(EventStatus status) {
  switch (status) {
    case EventStatus.published:
      return 'published';
    case EventStatus.concluded:
      return 'concluded';
    case EventStatus.archived:
      return 'archived';
    case EventStatus.draft:
      return 'draft';
  }
}

class EventModel {
  final String id;
  final String title;
  final String description;
  final String category;
  final String venue;
  final DateTime startTime;
  final DateTime endTime;
  final int capacity;
  final int registeredCount;
  final int checkedInCount;
  final String? bannerImageUrl;
  final String organizerId;
  final String club;
  final EventStatus status;
  final List<String> archivePhotos;
  final String? archiveSummary;
  final DateTime? createdAt;

  EventModel({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.venue,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    required this.registeredCount,
    required this.checkedInCount,
    required this.bannerImageUrl,
    required this.organizerId,
    required this.club,
    required this.status,
    required this.archivePhotos,
    required this.archiveSummary,
    required this.createdAt,
  });

  bool get isFull => registeredCount >= capacity;

  factory EventModel.fromMap(String id, Map<String, dynamic> map) {
    return EventModel(
      id: id,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      category: map['category'] as String? ?? '',
      venue: map['venue'] as String? ?? '',
      startTime: (map['startTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endTime: (map['endTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      capacity: (map['capacity'] as num?)?.toInt() ?? 0,
      registeredCount: (map['registeredCount'] as num?)?.toInt() ?? 0,
      checkedInCount: (map['checkedInCount'] as num?)?.toInt() ?? 0,
      bannerImageUrl: map['bannerImageUrl'] as String?,
      organizerId: map['organizerId'] as String? ?? '',
      club: map['club'] as String? ?? '',
      status: eventStatusFromString(map['status'] as String? ?? 'draft'),
      archivePhotos: List<String>.from(map['archivePhotos'] as List? ?? []),
      archiveSummary: map['archiveSummary'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'category': category,
      'venue': venue,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'capacity': capacity,
      'registeredCount': registeredCount,
      'checkedInCount': checkedInCount,
      'bannerImageUrl': bannerImageUrl,
      'organizerId': organizerId,
      'club': club,
      'status': eventStatusToString(status),
      'archivePhotos': archivePhotos,
      'archiveSummary': archiveSummary,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}
