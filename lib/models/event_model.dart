import 'package:cloud_firestore/cloud_firestore.dart';

enum EventStatus { draft, published, concluded, archived }

enum EventBadge { liveNow, upcoming, fullyBooked }

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
  final int waitlistCount;
  final bool certificateEnabled;
  final String? bannerImageUrl;
  final String organizerId;
  final EventStatus status;
  final List<String> archivePhotos;
  final String? archiveSummary;
  final String? activeCheckinToken;
  final DateTime? tokenGeneratedAt;
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
    this.waitlistCount = 0,
    this.certificateEnabled = false,
    required this.bannerImageUrl,
    required this.organizerId,
    required this.status,
    required this.archivePhotos,
    required this.archiveSummary,
    required this.createdAt,
    this.activeCheckinToken,
    this.tokenGeneratedAt,
  });

  bool get isFull => registeredCount >= capacity;

  /// Fully booked takes priority over live/upcoming since it's the more
  /// actionable thing for a browsing student to know.
  EventBadge badgeAt(DateTime now) {
    if (isFull) return EventBadge.fullyBooked;
    if (now.isAfter(startTime) && now.isBefore(endTime)) return EventBadge.liveNow;
    return EventBadge.upcoming;
  }

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
      waitlistCount: (map['waitlistCount'] as num?)?.toInt() ?? 0,
      certificateEnabled: map['certificateEnabled'] as bool? ?? false,
      bannerImageUrl: map['bannerImageUrl'] as String?,
      organizerId: map['organizerId'] as String? ?? '',
      status: eventStatusFromString(map['status'] as String? ?? 'draft'),
      archivePhotos: List<String>.from(map['archivePhotos'] as List? ?? []),
      archiveSummary: map['archiveSummary'] as String?,
      createdAt: (map['createdAt'] as Timestamp?)?.toDate(),
      activeCheckinToken: map['activeCheckinToken'] as String?,
      tokenGeneratedAt: (map['tokenGeneratedAt'] as Timestamp?)?.toDate(),
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
      'waitlistCount': waitlistCount,
      'certificateEnabled': certificateEnabled,
      'bannerImageUrl': bannerImageUrl,
      'organizerId': organizerId,
      'status': eventStatusToString(status),
      'archivePhotos': archivePhotos,
      'archiveSummary': archiveSummary,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'activeCheckinToken': activeCheckinToken,
      'tokenGeneratedAt': tokenGeneratedAt != null ? Timestamp.fromDate(tokenGeneratedAt!) : null,
    };
  }
}
