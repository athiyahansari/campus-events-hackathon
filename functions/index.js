const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const { getMessaging } = require('firebase-admin/messaging');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');

initializeApp();
const db = getFirestore();
const messaging = getMessaging();

// Mirrors lib/utils/clubs.dart — kept in sync manually since functions/ has no access to the
// Dart source. Used to sanity-check a user's `interests` before using them in a Firestore
// `in` query (which throws on an empty list).
const CAMPUS_CATEGORIES = [
  'Computing School',
  'Business School',
  'Student Council',
  'Engineering School',
  'School of Medicine',
  'Arts & Culture',
  'Sports Council',
  'Drama Society',
  'Music Society',
];

/**
 * Fires on every new doc in `notifications` — created either by the app (organizer releasing
 * a no-show seat) or by the scheduled functions below — and pushes it to the recipient's
 * device via FCM, using the token PushNotificationService (lib/services) captured on login.
 */
exports.sendPushOnNotificationCreate = onDocumentCreated('notifications/{notificationId}', async (event) => {
  const notification = event.data.data();
  const userDoc = await db.collection('users').doc(notification.userId).get();
  const token = userDoc.data()?.fcmToken;
  if (!token) {
    logger.info(`No FCM token for user ${notification.userId}, skipping push.`);
    return;
  }

  try {
    await messaging.send({
      token,
      notification: {
        title: notification.title,
        body: notification.body,
      },
    });
  } catch (err) {
    logger.warn(`Push failed for user ${notification.userId}: ${err.message}`);
    // A stale/uninstalled-app token fails permanently — clear it so we stop retrying it.
    if (err.code === 'messaging/registration-token-not-registered') {
      await userDoc.ref.update({ fcmToken: FieldValue.delete() });
    }
  }
});

/**
 * Runs hourly. For every registration not yet reminded, if its event starts within the next
 * 24 hours, writes a notification doc (sendPushOnNotificationCreate then pushes it) and marks
 * the registration so it isn't reminded twice.
 */
exports.sendEventReminders = onSchedule('every 60 minutes', async () => {
  const now = new Date();
  const in24h = new Date(now.getTime() + 24 * 60 * 60 * 1000);

  const dueRegistrations = await db.collection('registrations').where('reminderSent', '==', false).get();

  for (const doc of dueRegistrations.docs) {
    const reg = doc.data();
    const eventDoc = await db.collection('events').doc(reg.eventId).get();
    if (!eventDoc.exists) continue;

    const event = eventDoc.data();
    const startTime = event.startTime?.toDate();
    if (!startTime || startTime < now || startTime > in24h) continue;

    await db.collection('notifications').add({
      userId: reg.userId,
      title: `Reminder: ${event.title} is tomorrow`,
      body: `Starts ${startTime.toLocaleString('en-US', {
        month: 'short',
        day: 'numeric',
        hour: 'numeric',
        minute: '2-digit',
      })} at ${event.venue}.`,
      read: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    await doc.ref.update({ reminderSent: true });
  }
});

/**
 * Runs daily. For each student with interests and a saved push token, counts events matching
 * their interests that started since they were last active (or last nudged, whichever is more
 * recent) which they never registered for. Nudges once 2+ have piled up, then advances the
 * "already nudged up to" watermark so the same gap isn't renotified every day.
 */
exports.sendMissedEventsNudge = onSchedule('every 24 hours', async () => {
  const now = new Date();
  const usersSnap = await db.collection('users').where('role', '==', 'student').get();

  for (const userDoc of usersSnap.docs) {
    const user = userDoc.data();
    if (!user.fcmToken || !user.interests || user.interests.length === 0) continue;

    const interests = user.interests.filter((c) => CAMPUS_CATEGORIES.includes(c)).slice(0, 10);
    if (interests.length === 0) continue;

    const lastActiveAt = user.lastActiveAt?.toDate();
    const lastNudgeSentAt = user.lastNudgeSentAt?.toDate();
    const candidates = [lastActiveAt, lastNudgeSentAt].filter(Boolean);
    if (candidates.length === 0) continue; // never opened the app — nothing to compare against yet.
    const windowStart = candidates.sort((a, b) => b - a)[0];

    const registrationsSnap = await db.collection('registrations').where('userId', '==', userDoc.id).get();
    const registeredEventIds = new Set(registrationsSnap.docs.map((d) => d.data().eventId));

    const eventsSnap = await db.collection('events').where('category', 'in', interests).get();

    const missedCount = eventsSnap.docs.filter((d) => {
      const data = d.data();
      if (!['published', 'archived'].includes(data.status)) return false;
      if (registeredEventIds.has(d.id)) return false;
      const startTime = data.startTime?.toDate();
      return startTime && startTime > windowStart && startTime < now;
    }).length;

    if (missedCount >= 2) {
      await db.collection('notifications').add({
        userId: userDoc.id,
        title: "You've missed some events",
        body: "A couple of events matching your interests already happened while you were away — "
          + "check the feed to see what's coming up next.",
        read: false,
        createdAt: FieldValue.serverTimestamp(),
      });
      await userDoc.ref.update({ lastNudgeSentAt: FieldValue.serverTimestamp() });
    }
  }
});
