"use strict";

const ACTIVE_STATUSES = new Set(["pending", "sent", "received"]);

function isActiveInboxStatus(value) {
  return ACTIVE_STATUSES.has(value);
}

function createFamilyInboxFunctions({functions, admin, db}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  const markFamilyInboxRead = functions.https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }
    const familyId = data && data.familyId;
    if (typeof familyId !== "string" ||
        familyId.length < 1 ||
        familyId.length > 128 ||
        familyId.includes("/")) {
      throw new HttpsError("invalid-argument", "Famille invalide.");
    }

    const uid = context.auth.uid;
    const familyRef = db.collection("families").doc(familyId);
    const [familySnap, memberSnap] = await Promise.all([
      familyRef.get(),
      familyRef.collection("members").doc(uid).get(),
    ]);
    const family = familySnap.exists ? familySnap.data() : null;
    const member = memberSnap.exists ? memberSnap.data() : null;
    const isOwner = member && member.active === true &&
      member.uid === uid && member.role === "owner" &&
      family && family.ownerUid === uid;
    const isParent = member && member.active === true &&
      member.uid === uid && member.role === "parent";
    if (!isOwner && !isParent) {
      throw new HttpsError(
        "permission-denied",
        "Seul un parent actif peut lire cette boîte."
      );
    }

    const [requests, joins] = await Promise.all([
      familyRef.collection("requests").limit(200).get(),
      familyRef.collection("join_requests").limit(200).get(),
    ]);
    const batch = db.batch();
    let updated = 0;
    for (const document of [...requests.docs, ...joins.docs]) {
      const record = document.data();
      if (!isActiveInboxStatus(record.status)) continue;
      const patch = {
        readBy: fieldValue.arrayUnion(uid),
        updatedAt: fieldValue.serverTimestamp(),
      };
      if (document.ref.parent.id === "join_requests" &&
          (record.status === "pending" || record.status === "sent")) {
        patch.status = "received";
      }
      batch.update(document.ref, patch);
      updated++;
    }
    if (updated > 0) await batch.commit();
    return {updated};
  });

  return {markFamilyInboxRead};
}

module.exports = {
  ACTIVE_STATUSES,
  isActiveInboxStatus,
  createFamilyInboxFunctions,
};
