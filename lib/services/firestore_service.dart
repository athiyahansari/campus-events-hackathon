import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/event_model.dart';
import '../models/registration_model.dart';

class EventFullException implements Exception {
  @override
  String toString() => 'This event has reached capacity.';
}

class AlreadyRegisteredException implements Exception {
  @override
  String toString() => 'You are already registered for this event.';
}

class NotRegisteredException implements Exception {
  @override
  String toString() => "You're not registered for this event.";
}

class InvalidCheckinTokenException implements Exception {
  @override
  String toString() => 'This code has expired. Ask the organizer for the current check-in code.';
}

class AlreadyCheckedInException implements Exception {
  @override
  String toString() => "You're already checked in.";
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  CollectionReference<Map<String, dynamic>> get _events => _db.collection('events');
  CollectionReference<Map<String, dynamic>> get _registrations => _db.collection('registrations');

  // ---------------- Events ----------------

  Stream<List<EventModel>> publicEventFeed() {
    return _events.where('status', isEqualTo: 'published').snapshots().map((snap) {
      final events = snap.docs.map((d) => EventModel.fromMap(d.id, d.data())).toList();
      events.sort((a, b) => a.startTime.compareTo(b.startTime));
      return events;
    });
  }

  Stream<List<EventModel>> organizerEvents({required String organizerId}) {
    return _events.where('organizerId', isEqualTo: organizerId).snapshots().map((snap) {
      final events = snap.docs.map((d) => EventModel.fromMap(d.id, d.data())).toList();
      events.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return events;
    });
  }

  Stream<List<EventModel>> archivedEvents() {
    return _events.where('status', isEqualTo: 'archived').snapshots().map((snap) {
      final events = snap.docs.map((d) => EventModel.fromMap(d.id, d.data())).toList();
      events.sort((a, b) => b.startTime.compareTo(a.startTime));
      return events;
    });
  }

  Stream<EventModel?> watchEvent(String eventId) {
    return _events.doc(eventId).snapshots().map((d) => d.exists ? EventModel.fromMap(d.id, d.data()!) : null);
  }

  Future<String> createEvent(EventModel event) async {
    final doc = await _events.add(event.toMap());
    return doc.id;
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) {
    return _events.doc(eventId).update(updates);
  }

  Future<void> archiveEvent(String eventId, {required List<String> photos, required String summary}) {
    return _events.doc(eventId).update({
      'status': 'archived',
      'archivePhotos': photos,
      'archiveSummary': summary,
    });
  }

  /// Generates a fresh random token and publishes it as the event's live check-in code.
  /// Called both to start a session and to rotate it every 45s.
  Future<void> startCheckinSession(String eventId) {
    return _events.doc(eventId).update({
      'activeCheckinToken': _uuid.v4(),
      'tokenGeneratedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Invalidates the current token so no previously-displayed (or screenshotted) QR works anymore.
  Future<void> stopCheckinSession(String eventId) {
    return _events.doc(eventId).update({
      'activeCheckinToken': null,
      'tokenGeneratedAt': null,
    });
  }

  // ---------------- Registrations ----------------

  Stream<List<RegistrationModel>> userRegistrations(String userId) {
    return _registrations.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final regs = snap.docs.map((d) => RegistrationModel.fromMap(d.id, d.data())).toList();
      regs.sort((a, b) => (b.registeredAt ?? DateTime(0)).compareTo(a.registeredAt ?? DateTime(0)));
      return regs;
    });
  }

  Stream<RegistrationModel?> watchRegistration({required String eventId, required String userId}) {
    return _registrations.doc('${eventId}_$userId').snapshots().map(
          (d) => d.exists ? RegistrationModel.fromMap(d.id, d.data()!) : null,
        );
  }

  Stream<List<RegistrationModel>> eventRegistrations(String eventId) {
    return _registrations
        .where('eventId', isEqualTo: eventId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => RegistrationModel.fromMap(d.id, d.data())).toList());
  }

  Future<String> fetchUserName(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return (doc.data()?['name'] as String?) ?? 'Unknown student';
  }

  /// Registers [userId] for [eventId], enforcing capacity and one-registration-per-user
  /// atomically via transaction. Uses a deterministic doc ID so the duplicate check and
  /// the write happen inside the same transaction (no race between concurrent requests).
  Future<RegistrationModel> registerForEvent({
    required String eventId,
    required String userId,
  }) async {
    final registrationRef = _registrations.doc('${eventId}_$userId');
    final eventRef = _events.doc(eventId);

    await _db.runTransaction((tx) async {
      final existingSnap = await tx.get(registrationRef);
      if (existingSnap.exists) {
        throw AlreadyRegisteredException();
      }
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw Exception('Event not found.');
      }
      final data = eventSnap.data()!;
      final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
      final registeredCount = (data['registeredCount'] as num?)?.toInt() ?? 0;
      if (registeredCount >= capacity) {
        throw EventFullException();
      }
      tx.set(registrationRef, {
        'eventId': eventId,
        'userId': userId,
        'checkedIn': false,
        'checkedInAt': null,
        'registeredAt': FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {'registeredCount': registeredCount + 1});
    });

    final saved = await registrationRef.get();
    return RegistrationModel.fromMap(saved.id, saved.data()!);
  }

  /// Self-check-in: [userId] scanned [scannedToken] off the organizer's projected QR for
  /// [eventId]. Verifies they're actually registered, not already checked in, and that the
  /// scanned token matches the event's CURRENT live token (rejects stale/screenshotted codes
  /// once the organizer's display has rotated to a new one).
  Future<void> selfCheckIn({
    required String eventId,
    required String userId,
    required String scannedToken,
  }) async {
    final registrationRef = _registrations.doc('${eventId}_$userId');
    final eventRef = _events.doc(eventId);

    await _db.runTransaction((tx) async {
      final regSnap = await tx.get(registrationRef);
      if (!regSnap.exists) {
        throw NotRegisteredException();
      }
      final regData = regSnap.data()!;
      if (regData['checkedIn'] == true) {
        throw AlreadyCheckedInException();
      }

      final eventSnap = await tx.get(eventRef);
      final eventData = eventSnap.data();
      final currentToken = eventData?['activeCheckinToken'] as String?;
      if (currentToken == null || currentToken != scannedToken) {
        throw InvalidCheckinTokenException();
      }

      final checkedInCount = (eventData?['checkedInCount'] as num?)?.toInt() ?? 0;
      tx.update(registrationRef, {
        'checkedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
        'lastCheckinToken': scannedToken,
      });
      tx.update(eventRef, {'checkedInCount': checkedInCount + 1});
    });
  }
}
