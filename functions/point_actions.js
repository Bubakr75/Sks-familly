"use strict";

const crypto = require("node:crypto");
const {
  isDurableVerifiedAuth,
} = require("./family_access_control");

const ID = /^[^/\u0000-\u001f]{1,128}$/;
const PHOTO_PATH =
  /^families\/([^/]+)\/actions\/([^/]+)\/proof\.(jpg|png|webp)$/;

function cleanId(value, field) {
  if (typeof value !== "string" || !ID.test(value.trim())) {
    throw new Error(`INVALID_${field.toUpperCase()}`);
  }
  return value.trim();
}

function normalizePointAction(data) {
  const familyId = cleanId(data && data.familyId, "family_id");
  const actionId = cleanId(data && data.actionId, "action_id");
  const childId = cleanId(data && data.childId, "child_id");
  const amount = data && data.amount;
  const reason = data && data.reason;
  const category = data && data.category;
  const isBonus = data && data.isBonus;
  if (!Number.isInteger(amount) || amount < 1 || amount > 999) {
    throw new Error("INVALID_AMOUNT");
  }
  if (typeof reason !== "string" ||
      reason.trim().length < 1 ||
      reason.trim().length > 500 ||
      /[\u0000-\u001f]/.test(reason)) {
    throw new Error("INVALID_REASON");
  }
  if (typeof category !== "string" ||
      category.trim().length < 1 ||
      category.trim().length > 80) {
    throw new Error("INVALID_CATEGORY");
  }
  if (typeof isBonus !== "boolean") throw new Error("INVALID_ACTION_TYPE");

  let photoStoragePath = null;
  if (data.photoStoragePath != null) {
    if (typeof data.photoStoragePath !== "string") {
      throw new Error("INVALID_PHOTO_PATH");
    }
    const match = PHOTO_PATH.exec(data.photoStoragePath);
    if (!match || match[1] !== familyId || match[2] !== actionId) {
      throw new Error("INVALID_PHOTO_PATH");
    }
    photoStoragePath = data.photoStoragePath;
  }
  return {
    familyId,
    actionId,
    childId,
    amount,
    reason: reason.trim(),
    category: category.trim(),
    isBonus,
    photoStoragePath,
  };
}

function normalizeHistoryEvent(data) {
  const familyId = cleanId(data && data.familyId, "family_id");
  const eventId = cleanId(data && data.eventId, "event_id");
  const childId = cleanId(data && data.childId, "child_id");
  const points = data && data.points;
  const reason = data && data.reason;
  const category = data && data.category;
  const isBonus = data && data.isBonus;
  if (!Number.isInteger(points) || points < 0 || points > 100000) {
    throw new Error("INVALID_POINTS");
  }
  if (typeof reason !== "string" ||
      reason.trim().length < 1 ||
      reason.trim().length > 500) {
    throw new Error("INVALID_REASON");
  }
  if (typeof category !== "string" ||
      category.trim().length < 1 ||
      category.trim().length > 80 ||
      typeof isBonus !== "boolean") {
    throw new Error("INVALID_EVENT");
  }
  return {
    familyId,
    eventId,
    childId,
    points,
    reason: reason.trim(),
    category: category.trim(),
    isBonus,
    transferId: typeof data.transferId === "string"
      ? cleanId(data.transferId, "transfer_id") : null,
    counterpartyChildId: typeof data.counterpartyChildId === "string"
      ? cleanId(data.counterpartyChildId, "counterparty_child_id") : null,
  };
}

function resolveActor({
  uid,
  family,
  member,
  managerDurableVerified = false,
}) {
  if (!member || member.active !== true || member.uid !== uid) return null;
  let role = null;
  if (member.role === "owner" && family && family.ownerUid === uid) {
    role = "owner";
  } else if (member.role === "parent") {
    role = "parent";
  } else if (
    ["manager", "familyAdmin"].includes(member.role) &&
    managerDurableVerified
  ) {
    role = "manager";
  }
  if (!role) return null;
  const rawName = typeof member.displayName === "string"
    ? member.displayName.trim() : "";
  return {
    actorUid: uid,
    actorDisplayName: rawName.length > 0 && rawName.length <= 80
      ? rawName : (role === "owner" ? "Propriétaire" : "Parent"),
    actorRole: role,
  };
}

function fingerprint(action, uid) {
  return crypto.createHash("sha256")
    .update(JSON.stringify({...action, uid}))
    .digest("hex");
}

function buildPointHistory({
  action,
  actor,
  actualAmount,
  createdAt,
  serverDate,
}) {
  return {
    id: action.actionId,
    childId: action.childId,
    points: actualAmount,
    reason: action.reason,
    category: action.category,
    isBonus: action.isBonus,
    date: serverDate,
    createdAt,
    actorUid: actor.actorUid,
    actorDisplayName: actor.actorDisplayName,
    actorRole: actor.actorRole,
    actionBy: actor.actorDisplayName,
    proofPhotoPath: action.photoStoragePath,
  };
}

function validatePhotoMetadata(action, metadata) {
  if (!action.photoStoragePath) return;
  const contentType = metadata && metadata.contentType;
  const size = Number(metadata && metadata.size);
  if (!["image/jpeg", "image/png", "image/webp"].includes(contentType) ||
      !Number.isFinite(size) ||
      size < 1 ||
      size > 5 * 1024 * 1024) {
    throw new Error("INVALID_PHOTO_METADATA");
  }
}

function createPointActionFunctions({functions, admin, db}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  function fail(error) {
    if (error instanceof HttpsError) return error;
    if (error && typeof error.message === "string" &&
        error.message.startsWith("INVALID_")) {
      return new HttpsError("invalid-argument", "Action de points invalide.");
    }
    console.error("Point action error:", error);
    return new HttpsError("internal", "L'action n'a pas pu être enregistrée.");
  }

  const recordPointAction = functions.https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.uid) {
        throw new HttpsError("unauthenticated", "Authentification requise.");
      }
      const uid = context.auth.uid;
      const action = normalizePointAction(data);
      if (action.photoStoragePath) {
        try {
          const [metadata] = await admin.storage()
            .bucket()
            .file(action.photoStoragePath)
            .getMetadata();
          validatePhotoMetadata(action, metadata);
        } catch (error) {
          if (error && error.message === "INVALID_PHOTO_METADATA") throw error;
          throw new Error("INVALID_PHOTO_METADATA");
        }
      }
      const familyRef = db.collection("families").doc(action.familyId);
      const memberRef = familyRef.collection("members").doc(uid);
      const childRef = familyRef.collection("children").doc(action.childId);
      const historyRef = familyRef.collection("history").doc(action.actionId);
      const operationRef =
        familyRef.collection("_operations").doc(action.actionId);
      const actionFingerprint = fingerprint(action, uid);

      return await db.runTransaction(async (tx) => {
        const [familySnap, memberSnap, childSnap, operationSnap] =
          await Promise.all([
            tx.get(familyRef),
            tx.get(memberRef),
            tx.get(childRef),
            tx.get(operationRef),
          ]);
        if (!familySnap.exists || !childSnap.exists) {
          throw new HttpsError("not-found", "Famille ou enfant introuvable.");
        }
        const actor = resolveActor({
          uid,
          family: familySnap.data(),
          member: memberSnap.exists ? memberSnap.data() : null,
          managerDurableVerified: isDurableVerifiedAuth(context),
        });
        if (!actor) {
          throw new HttpsError(
            "permission-denied",
            "Un parent actif est requis."
          );
        }
        if (operationSnap.exists) {
          const existing = operationSnap.data();
          if (existing.fingerprint !== actionFingerprint) {
            throw new HttpsError(
              "already-exists",
              "Cet identifiant est déjà utilisé."
            );
          }
          return {...existing.result, idempotent: true};
        }

        const child = childSnap.data();
        if (!Number.isInteger(child.points) || child.points < 0) {
          throw new HttpsError(
            "failed-precondition",
            "Solde de points invalide."
          );
        }
        const actualAmount = action.isBonus
          ? action.amount : Math.min(action.amount, child.points);
        if (actualAmount < 1) {
          throw new HttpsError(
            "failed-precondition",
            "Aucun point ne peut être retiré."
          );
        }
        const newBalance = action.isBonus
          ? child.points + actualAmount : child.points - actualAmount;
        const createdAt = fieldValue.serverTimestamp();
        const serverDate = new Date().toISOString();
        const history = buildPointHistory({
          action,
          actor,
          actualAmount,
          createdAt,
          serverDate,
        });
        const result = {
          history: {...history, createdAt: serverDate},
          newBalance,
        };
        tx.update(childRef, {points: newBalance});
        tx.create(historyRef, history);
        tx.create(operationRef, {
          fingerprint: actionFingerprint,
          operation: "point_action",
          actorUid: uid,
          createdAt,
          result,
        });
        return {...result, idempotent: false};
      });
    } catch (error) {
      throw fail(error);
    }
  });

  const recordHistoryEvent = functions.https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.uid) {
        throw new HttpsError("unauthenticated", "Authentification requise.");
      }
      const uid = context.auth.uid;
      const event = normalizeHistoryEvent(data);
      const familyRef = db.collection("families").doc(event.familyId);
      const memberRef = familyRef.collection("members").doc(uid);
      const childRef = familyRef.collection("children").doc(event.childId);
      const historyRef = familyRef.collection("history").doc(event.eventId);
      return await db.runTransaction(async (tx) => {
        const [familySnap, memberSnap, childSnap, historySnap] =
          await Promise.all([
            tx.get(familyRef),
            tx.get(memberRef),
            tx.get(childRef),
            tx.get(historyRef),
          ]);
        if (!familySnap.exists || !childSnap.exists) {
          throw new HttpsError("not-found", "Famille ou enfant introuvable.");
        }
        const actor = resolveActor({
          uid,
          family: familySnap.data(),
          member: memberSnap.exists ? memberSnap.data() : null,
          managerDurableVerified: isDurableVerifiedAuth(context),
        });
        if (!actor) {
          throw new HttpsError("permission-denied", "Parent actif requis.");
        }
        if (historySnap.exists) {
          return {history: historySnap.data(), idempotent: true};
        }
        const createdAt = fieldValue.serverTimestamp();
        const serverDate = new Date().toISOString();
        const history = {
          id: event.eventId,
          childId: event.childId,
          points: event.points,
          reason: event.reason,
          category: event.category,
          isBonus: event.isBonus,
          date: serverDate,
          createdAt,
          actorUid: actor.actorUid,
          actorDisplayName: actor.actorDisplayName,
          actorRole: actor.actorRole,
          actionBy: actor.actorDisplayName,
          transferId: event.transferId,
          counterpartyChildId: event.counterpartyChildId,
        };
        tx.create(historyRef, history);
        return {
          history: {...history, createdAt: serverDate},
          idempotent: false,
        };
      });
    } catch (error) {
      throw fail(error);
    }
  });

  const setMemberDisplayName = functions.https.onCall(async (data, context) => {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }
    const familyId = cleanId(data && data.familyId, "family_id");
    const displayName = data && data.displayName;
    if (typeof displayName !== "string" ||
        displayName.trim().length < 1 ||
        displayName.trim().length > 80 ||
        /[\u0000-\u001f]/.test(displayName)) {
      throw new HttpsError("invalid-argument", "Nom invalide.");
    }
    const uid = context.auth.uid;
    const familyRef = db.collection("families").doc(familyId);
    const memberRef = familyRef.collection("members").doc(uid);
    await db.runTransaction(async (tx) => {
      const [familySnap, memberSnap] = await Promise.all([
        tx.get(familyRef), tx.get(memberRef),
      ]);
      const actor = resolveActor({
        uid,
        family: familySnap.exists ? familySnap.data() : null,
        member: memberSnap.exists ? memberSnap.data() : null,
        managerDurableVerified: isDurableVerifiedAuth(context),
      });
      if (!actor) {
        throw new HttpsError("permission-denied", "Parent actif requis.");
      }
      tx.update(memberRef, {
        displayName: displayName.trim(),
        displayNameUpdatedAt: fieldValue.serverTimestamp(),
      });
    });
    return {displayName: displayName.trim()};
  });

  return {recordPointAction, recordHistoryEvent, setMemberDisplayName};
}

module.exports = {
  normalizePointAction,
  normalizeHistoryEvent,
  resolveActor,
  fingerprint,
  buildPointHistory,
  validatePhotoMetadata,
  createPointActionFunctions,
};
