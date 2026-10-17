"use strict";

const {isAuthenticatedFamilyOwner} = require("./family_owner_authorization");
const pending = (data) => Boolean(data &&
  ["pending", "sent", "received"].includes(data.status));

// Une nouvelle soumission peut remplacer un document précédemment refusé.
// Les changements de lecture et le marquage d'envoi ne sont pas des demandes.
function isJoinSubmission(before, after) {
  return pending(after) && (!pending(before) ||
    (Number.isSafeInteger(after.notificationRevision) &&
      after.notificationRevision > (before.notificationRevision || 0)));
}

function sameSubmission(event, current) {
  const a = event && event.createdAt;
  const b = current && current.createdAt;
  return Boolean(a && b && a.seconds === b.seconds &&
    a.nanoseconds === b.nanoseconds &&
    (event.notificationRevision || 0) === (current.notificationRevision || 0));
}

async function parentRecipientUids({familySnapshot, members, admin, HttpsError}) {
  const family = familySnapshot.data();
  const uids = new Set();
  const ownerUid = family.ownerUid;
  if (ownerUid) {
    const owner = members.find((doc) => doc.id === ownerUid);
    try {
      // Même vérification que l'approbation, sans réparer ni écrire de données.
      isAuthenticatedFamilyOwner({context: {auth: {uid: ownerUid}},
        familySnapshot, memberSnapshot: owner || {exists: false},
        HttpsError, allowRepair: true});
      uids.add(ownerUid);
    } catch (_) { /* Identité incohérente ou propriétaire désactivé. */ }
  }
  for (const doc of members) {
    const member = doc.data();
    if (doc.id === ownerUid || member.uid !== doc.id ||
        member.active !== true ||
        !["parent", "manager", "familyAdmin"].includes(member.role)) continue;
    if (["manager", "familyAdmin"].includes(member.role)) {
      try {
        const user = await admin.auth().getUser(member.uid);
        if (user.disabled || !user.emailVerified ||
            !user.providerData.some((p) => p.providerId !== "anonymous")) continue;
      } catch (_) { continue; }
    }
    uids.add(member.uid);
  }
  return uids;
}

function createJoinNotificationHandler({db, admin, HttpsError}) {
  return async (snap, context) => {
    const req = snap.data();
    if (!pending(req)) return;
    const familyId = context.params.familyId;
    try {
      const familyRef = db.collection("families").doc(familyId);
      const familySnapshot = await familyRef.get();
      if (!familySnapshot.exists || !familySnapshot.data().ownerUid) {
        console.log("join_notification: famille ou propriétaire canonique absent");
        return;
      }
      const members = await familyRef.collection("members").get();
      const uids = await parentRecipientUids({familySnapshot,
        members: members.docs, admin, HttpsError});
      const devices = await familyRef.collection("fcm_tokens").get();
      const tokens = [...new Set(devices.docs.filter((doc) => {
        const data = doc.data();
        return doc.id !== req.deviceId && data.disabled !== true &&
          uids.has(data.uid) && typeof data.token === "string" && data.token.trim();
      }).map((doc) => doc.data().token))];
      if (!tokens.length) {
        console.log("join_notification: aucun appareil parent destinataire", {
          parentCount: uids.size, deviceCount: devices.docs.length});
        return;
      }
      const claimed = await db.runTransaction(async (transaction) => {
        const current = await transaction.get(snap.ref);
        if (!current.exists || !pending(current.data()) ||
            current.data().notificationEventId ||
            !sameSubmission(req, current.data())) return false;
        transaction.update(snap.ref, {notificationEventId: context.eventId});
        return true;
      });
      if (!claimed) return;
      const title = "📱 Nouvelle demande de rattachement";
      const body = "Une demande d’appareil attend votre consultation dans SKS Family.";
      const message = {
        notification: {title, body},
        data: {sender: req.deviceId || "", type: "join_request",
          requestId: context.params.requestId, familyId},
        android: {priority: "high", notification: {
          channelId: "sks_family_channel", icon: "@mipmap/ic_launcher",
          sound: "default", priority: "high"}},
        webpush: {headers: {Urgency: "high"}, notification: {
          title, body, icon: "/icons/Icon-192.png", badge: "/icons/Icon-192.png",
          requireInteraction: true},
        fcmOptions: {link: "https://sks-familly-3f205.web.app"}},
      };
      // FCM limite chaque lot à 500 appareils.
      for (let offset = 0; offset < tokens.length; offset += 500) {
        const response = await admin.messaging().sendEachForMulticast({
          ...message, tokens: tokens.slice(offset, offset + 500)});
        console.log("join_notification: résultat", {
          sent: response.successCount, failed: response.failureCount,
          errors: response.responses.filter((r) => !r.success)
              .map((r) => r.error && r.error.code)});
      }
    } catch (error) {
      console.error("join_notification: échec", {code: error.code || "unknown"});
    }
  };
}

module.exports = {isJoinSubmission, sameSubmission, parentRecipientUids,
  createJoinNotificationHandler};
