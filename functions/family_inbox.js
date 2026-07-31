"use strict";

const {
  FAMILY_PERMISSIONS,
  authorizeFamilyPermission,
} = require("./family_access_control");

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
    const authorization = authorizeFamilyPermission({
      context,
      familySnapshot: familySnap,
      memberSnapshot: memberSnap,
      HttpsError,
      permission: FAMILY_PERMISSIONS.READ_INBOX,
    });
    const canManageJoins =
      authorization.role === "owner" ||
      authorization.role === "manager";

    const [requests, joins] = await Promise.all([
      familyRef.collection("requests").limit(200).get(),
      familyRef.collection("join_requests").limit(200).get(),
    ]);
    const batch = db.batch();
    let updated = 0;
    const documents = canManageJoins
      ? [...requests.docs, ...joins.docs]
      : requests.docs;
    for (const document of documents) {
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
