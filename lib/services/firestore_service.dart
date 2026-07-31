import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';

import '../models/event_model.dart';
import '../models/notification_model.dart';
import '../models/registration_model.dart';
import '../models/waitlist_model.dart';

enum RegistrationOutcome { registered, waitlisted }

class AlreadyRegisteredException implements Exception {
  @override
  String toString() => 'You are already registered for this event.';
}

class AlreadyWaitlistedException implements Exception {
  @override
  String toString() => "You're already on the waitlist for this event.";
}

class EmptyWaitlistException implements Exception {
  @override
  String toString() => 'No one is on the waitlist for this event.';
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
  CollectionReference<Map<String, dynamic>> get _waitlist => _db.collection('waitlist');
  CollectionReference<Map<String, dynamic>> get _notifications => _db.collection('notifications');

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
  /// If the event is already at capacity, adds [userId] to the waitlist instead so an
  /// organizer can promote them later via [releaseNoShowSeat].
  Future<RegistrationOutcome> registerForEvent({
    required String eventId,
    required String userId,
  }) async {
    final registrationRef = _registrations.doc('${eventId}_$userId');
    final waitlistRef = _waitlist.doc('${eventId}_$userId');
    final eventRef = _events.doc(eventId);

    return _db.runTransaction((tx) async {
      final existingReg = await tx.get(registrationRef);
      if (existingReg.exists) {
        throw AlreadyRegisteredException();
      }
      final existingWaitlist = await tx.get(waitlistRef);
      if (existingWaitlist.exists) {
        throw AlreadyWaitlistedException();
      }
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw Exception('Event not found.');
      }
      final data = eventSnap.data()!;
      final capacity = (data['capacity'] as num?)?.toInt() ?? 0;
      final registeredCount = (data['registeredCount'] as num?)?.toInt() ?? 0;

      if (registeredCount >= capacity) {
        final waitlistCount = (data['waitlistCount'] as num?)?.toInt() ?? 0;
        tx.set(waitlistRef, {
          'eventId': eventId,
          'userId': userId,
          'joinedAt': FieldValue.serverTimestamp(),
        });
        tx.update(eventRef, {'waitlistCount': waitlistCount + 1});
        return RegistrationOutcome.waitlisted;
      }

      tx.set(registrationRef, {
        'eventId': eventId,
        'userId': userId,
        'checkedIn': false,
        'checkedInAt': null,
        'registeredAt': FieldValue.serverTimestamp(),
      });
      tx.update(eventRef, {'registeredCount': registeredCount + 1});
      return RegistrationOutcome.registered;
    });
  }

  // ---------------- Waitlist ----------------

  Stream<WaitlistModel?> watchWaitlistEntry({required String eventId, required String userId}) {
    return _waitlist.doc('${eventId}_$userId').snapshots().map(
          (d) => d.exists ? WaitlistModel.fromMap(d.id, d.data()!) : null,
        );
  }

  Stream<List<WaitlistModel>> userWaitlistEntries(String userId) {
    return _waitlist.where('userId', isEqualTo: userId).snapshots().map(
          (snap) => snap.docs.map((d) => WaitlistModel.fromMap(d.id, d.data())).toList(),
        );
  }

  Stream<List<WaitlistModel>> eventWaitlist(String eventId) {
    return _waitlist.where('eventId', isEqualTo: eventId).snapshots().map((snap) {
      final entries = snap.docs.map((d) => WaitlistModel.fromMap(d.id, d.data())).toList();
      entries.sort((a, b) => (a.joinedAt ?? DateTime(0)).compareTo(b.joinedAt ?? DateTime(0)));
      return entries;
    });
  }

  /// Releases a no-show's seat and, if anyone is waitlisted, immediately promotes the best
  /// match — the waitlisted student whose interests include the event's category — to
  /// registered, notifying them. Falls back to first-come-first-served among equally matched
  /// (or unmatched) students via waitlist join order.
  Future<void> releaseNoShowSeat({
    required String eventId,
    required String noShowRegistrationId,
  }) async {
    final eventRef = _events.doc(eventId);
    final noShowRef = _registrations.doc(noShowRegistrationId);

    final waitlistSnap = await _waitlist.where('eventId', isEqualTo: eventId).get();
    final entries = waitlistSnap.docs.map((d) => WaitlistModel.fromMap(d.id, d.data())).toList()
      ..sort((a, b) => (a.joinedAt ?? DateTime(0)).compareTo(b.joinedAt ?? DateTime(0)));

    WaitlistModel? promoted;
    if (entries.isNotEmpty) {
      final eventDoc = await eventRef.get();
      final category = eventDoc.data()?['category'] as String? ?? '';
      final profiles = await Future.wait(entries.map((e) => _db.collection('users').doc(e.userId).get()));

      var bestScore = -1;
      for (var i = 0; i < entries.length; i++) {
        final interests = List<String>.from(profiles[i].data()?['interests'] as List? ?? []);
        final score = interests.contains(category) ? 1 : 0;
        if (score > bestScore) {
          bestScore = score;
          promoted = entries[i];
        }
      }
    }

    final registrationRef = promoted != null ? _registrations.doc('${eventId}_${promoted.userId}') : null;
    final waitlistRef = promoted != null ? _waitlist.doc(promoted.id) : null;

    await _db.runTransaction((tx) async {
      final eventSnap = await tx.get(eventRef);
      if (!eventSnap.exists) {
        throw Exception('Event not found.');
      }
      final data = eventSnap.data()!;
      final registeredCount = (data['registeredCount'] as num?)?.toInt() ?? 0;
      final waitlistCount = (data['waitlistCount'] as num?)?.toInt() ?? 0;

      tx.delete(noShowRef);
      final updates = <String, dynamic>{
        'registeredCount': registeredCount > 0 ? registeredCount - 1 : 0,
      };

      if (promoted != null && registrationRef != null && waitlistRef != null) {
        tx.set(registrationRef, {
          'eventId': eventId,
          'userId': promoted.userId,
          'checkedIn': false,
          'checkedInAt': null,
          'registeredAt': FieldValue.serverTimestamp(),
        });
        tx.delete(waitlistRef);
        // A seat was freed and immediately refilled, so registeredCount is unchanged;
        // only the waitlist shrinks.
        updates['registeredCount'] = registeredCount;
        updates['waitlistCount'] = waitlistCount > 0 ? waitlistCount - 1 : 0;
      }

      tx.update(eventRef, updates);
    });

    if (promoted != null) {
      await sendNotification(
        userId: promoted.userId,
        title: 'A seat opened up!',
        body: 'A spot just opened up for an event on your waitlist — you\'re registered. Check My Tickets.',
      );
    }
  }

  // ---------------- Notifications ----------------

  Future<void> sendNotification({
    required String userId,
    required String title,
    required String body,
  }) {
    return _notifications.add({
      'userId': userId,
      'title': title,
      'body': body,
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<NotificationModel>> userNotifications(String userId) {
    return _notifications.where('userId', isEqualTo: userId).snapshots().map((snap) {
      final items = snap.docs.map((d) => NotificationModel.fromMap(d.id, d.data())).toList();
      items.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return items;
    });
  }

  Future<void> markNotificationRead(String notificationId) {
    return _notifications.doc(notificationId).update({'read': true});
  }

  /// Stores the device's current FCM token so the `sendPushOnNotificationCreate` Cloud
  /// Function (see functions/index.js) can target it. Called on login and on token refresh.
  Future<void> savePushToken(String userId, String token) {
    return _db.collection('users').doc(userId).update({'fcmToken': token});
  }

  /// Records that [userId] opened the app. The `sendMissedEventsNudge` scheduled Cloud
  /// Function uses this as the baseline for "events that happened while you were away" —
  /// see functions/index.js.
  Future<void> recordAppOpen(String userId) {
    return _db.collection('users').doc(userId).update({'lastActiveAt': FieldValue.serverTimestamp()});
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
