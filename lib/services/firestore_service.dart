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

class InvalidTicketException implements Exception {
  @override
  String toString() => 'This QR code is not valid for this event.';
}

class AlreadyCheckedInException implements Exception {
  @override
  String toString() => 'This ticket has already been checked in.';
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
    final qrCodeData = _uuid.v4();
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
        'qrCodeData': qrCodeData,
        'checkedIn': false,
        'checkedInAt': null,
        'registeredAt': FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {'registeredCount': registeredCount + 1});
    });

    final saved = await registrationRef.get();
    return RegistrationModel.fromMap(saved.id, saved.data()!);
  }

  /// Checks in a ticket by scanned [qrCodeData], validating it belongs to [expectedEventId].
  Future<RegistrationModel> checkIn({
    required String qrCodeData,
    required String expectedEventId,
  }) async {
    final matches = await _registrations.where('qrCodeData', isEqualTo: qrCodeData).limit(1).get();
    if (matches.docs.isEmpty) {
      throw InvalidTicketException();
    }
    final regDoc = matches.docs.first;
    if (regDoc.data()['eventId'] != expectedEventId) {
      throw InvalidTicketException();
    }

    final eventRef = _events.doc(expectedEventId);
    await _db.runTransaction((tx) async {
      final regSnap = await tx.get(regDoc.reference);
      final regData = regSnap.data()!;
      if (regData['eventId'] != expectedEventId) {
        throw InvalidTicketException();
      }
      if (regData['checkedIn'] == true) {
        throw AlreadyCheckedInException();
      }
      final eventSnap = await tx.get(eventRef);
      final checkedInCount = (eventSnap.data()?['checkedInCount'] as num?)?.toInt() ?? 0;
      tx.update(regDoc.reference, {
        'checkedIn': true,
        'checkedInAt': FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {'checkedInCount': checkedInCount + 1});
    });

    final updated = await regDoc.reference.get();
    return RegistrationModel.fromMap(updated.id, updated.data()!);
  }
}
