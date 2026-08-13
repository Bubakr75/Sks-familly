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

  let penaltyLinesCount = null;
  let penaltyLinesInstruction = null;
  if (data.penaltyLinesCount != null) {
    if (isBonus || !Number.isInteger(data.penaltyLinesCount) ||
        data.penaltyLinesCount < 1 || data.penaltyLinesCount > 10000) {
      throw new Error("INVALID_PENALTY_LINES_COUNT");
    }
    penaltyLinesCount = data.penaltyLinesCount;
    if (data.penaltyLinesInstruction != null) {
      if (typeof data.penaltyLinesInstruction !== "string" ||
          data.penaltyLinesInstruction.trim().length > 500 ||
          /[\u0000-\u001f]/.test(data.penaltyLinesInstruction)) {
        throw new Error("INVALID_PENALTY_LINES_INSTRUCTION");
      }
      penaltyLinesInstruction = data.penaltyLinesInstruction.trim();
    }
  } else if (data.penaltyLinesInstruction != null &&
      String(data.penaltyLinesInstruction).trim() !== "") {
    throw new Error("INVALID_PENALTY_LINES_INSTRUCTION");
  }

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
    penaltyLinesCount,
    penaltyLinesInstruction,
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
  const history = {
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
  if (action.penaltyLinesCount != null) {
    history.hasPenaltyLines = true;
    history.penaltyLinesCount = action.penaltyLinesCount;
    history.penaltyLinesInstruction = action.penaltyLinesInstruction;
    history.penaltyLinesStatus = "pending";
  } else if (!action.isBonus) {
    history.hasPenaltyLines = false;
  }
  return history;
}

function buildPenaltyLines({action, actor, createdAt, serverDate}) {
  if (action.isBonus) return null;
  const hasPenaltyLines = action.penaltyLinesCount != null;
  const count = action.penaltyLinesCount || 0;
  return {
    id: action.actionId,
    penaltyHistoryId: action.actionId,
    childId: action.childId,
    text: action.penaltyLinesInstruction || "",
    totalLines: count,
    completedLines: 0,
    createdAt,
    photoUrls: [],
    pendingValidation: false,
    hasPenaltyLines,
    penaltyLinesCount: count,
    penaltyLinesInstruction: action.penaltyLinesInstruction || "",
    penaltyLinesStatus: hasPenaltyLines ? "pending" : "completed",
    penaltyLinesCompletedAt: null,
    penaltyLinesCompletedBy: null,
    createdBy: actor.actorUid,
    serverDate,
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
      const punishmentRef =
        familyRef.collection("punishments").doc(action.actionId);
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
          return {...existing.result, status: "committed", idempotent: true};
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
        const punishment = buildPenaltyLines({
          action,
          actor,
          createdAt,
          serverDate,
        });
        const result = {
          history: {...history, createdAt: serverDate},
          newBalance,
          punishment: punishment
            ? {...punishment, createdAt: serverDate}
            : null,
        };
        tx.update(childRef, {points: newBalance});
        tx.create(historyRef, history);
        if (punishment) tx.create(punishmentRef, punishment);
        tx.create(operationRef, {
          fingerprint: actionFingerprint,
          operation: "point_action",
          operationId: action.actionId,
          status: "committed",
          actorUid: uid,
          createdAt,
          committedAt: createdAt,
          result,
        });
        return {...result, status: "committed", idempotent: false};
      });
    } catch (error) {
      throw fail(error);
    }
  });

  const getPointActionStatus = functions.https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.uid) {
        throw new HttpsError("unauthenticated", "Authentification requise.");
      }
      const familyId = cleanId(data && data.familyId, "family_id");
      const operationId = cleanId(
        data && (data.operationId || data.actionId),
        "operation_id"
      );
      const familyRef = db.collection("families").doc(familyId);
      const memberRef = familyRef.collection("members").doc(context.auth.uid);
      const operationRef = familyRef.collection("_operations").doc(operationId);
      const [familySnap, memberSnap, operationSnap] = await Promise.all([
        familyRef.get(),
        memberRef.get(),
        operationRef.get(),
      ]);
      const actor = resolveActor({
        uid: context.auth.uid,
        family: familySnap.exists ? familySnap.data() : null,
        member: memberSnap.exists ? memberSnap.data() : null,
        managerDurableVerified: isDurableVerifiedAuth(context),
      });
      if (!actor) {
        throw new HttpsError("permission-denied", "Un parent actif est requis.");
      }
      if (!operationSnap.exists) {
        return {operationId, status: "unknown"};
      }
      const operation = operationSnap.data();
      if (operation.operation !== "point_action" ||
          operation.actorUid !== context.auth.uid) {
        throw new HttpsError("permission-denied", "Opération inaccessible.");
      }
      const status = operation.status || "committed";
      if (status === "committed") {
        return {operationId, status, result: operation.result};
      }
      if (status === "rejected") {
        return {operationId, status, errorCode: operation.errorCode || "internal"};
      }
      return {operationId, status: "processing"};
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

  async function requireParent(context, familyId) {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError("unauthenticated", "Authentification requise.");
    }
    const uid = context.auth.uid;
    const familyRef = db.collection("families").doc(familyId);
    const memberRef = familyRef.collection("members").doc(uid);
    const [familySnap, memberSnap] = await Promise.all([
      familyRef.get(),
      memberRef.get(),
    ]);
    const actor = resolveActor({
      uid,
      family: familySnap.exists ? familySnap.data() : null,
      member: memberSnap.exists ? memberSnap.data() : null,
      managerDurableVerified: isDurableVerifiedAuth(context),
    });
    if (!actor) {
      throw new HttpsError("permission-denied", "Un parent actif est requis.");
    }
    return {actor, familyRef};
  }

  const completePenaltyLines = functions.https.onCall(async (data, context) => {
    try {
      const familyId = cleanId(data && data.familyId, "family_id");
      const punishmentId = cleanId(
        data && data.punishmentId,
        "punishment_id"
      );
      const {actor, familyRef} = await requireParent(context, familyId);
      const punishmentRef = familyRef.collection("punishments").doc(punishmentId);
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(punishmentRef);
        if (!snap.exists || snap.data().hasPenaltyLines !== true) {
          throw new HttpsError("not-found", "Lignes de pénalité introuvables.");
        }
        tx.update(punishmentRef, {
          completedLines: snap.data().penaltyLinesCount,
          penaltyLinesStatus: "completed",
          penaltyLinesCompletedAt: fieldValue.serverTimestamp(),
          penaltyLinesCompletedBy: actor.actorUid,
          pendingValidation: false,
        });
      });
      const saved = await punishmentRef.get();
      return {punishment: {id: saved.id, ...saved.data()}};
    } catch (error) {
      throw fail(error);
    }
  });

  const updatePenaltyLines = functions.https.onCall(async (data, context) => {
    try {
      const familyId = cleanId(data && data.familyId, "family_id");
      const punishmentId = cleanId(
        data && data.punishmentId,
        "punishment_id"
      );
      if (typeof data.hasPenaltyLines !== "boolean") {
        throw new Error("INVALID_PENALTY_LINES_STATE");
      }
      const {actor, familyRef} = await requireParent(context, familyId);
      const punishmentRef = familyRef.collection("punishments").doc(punishmentId);
      const snap = await punishmentRef.get();
      if (!snap.exists || typeof snap.data().penaltyHistoryId !== "string") {
        throw new HttpsError("not-found", "Pénalité liée introuvable.");
      }
      const instruction = data.penaltyLinesInstruction == null
        ? "" : data.penaltyLinesInstruction;
      if (data.hasPenaltyLines &&
          (!Number.isInteger(data.penaltyLinesCount) ||
           data.penaltyLinesCount < 1 || data.penaltyLinesCount > 10000)) {
        throw new Error("INVALID_PENALTY_LINES_COUNT");
      }
      if (typeof instruction !== "string" || instruction.trim().length > 500 ||
          /[\u0000-\u001f]/.test(instruction)) {
        throw new Error("INVALID_PENALTY_LINES_INSTRUCTION");
      }
      const patch = data.hasPenaltyLines ? {
        hasPenaltyLines: true,
        totalLines: data.penaltyLinesCount,
        penaltyLinesCount: data.penaltyLinesCount,
        text: instruction.trim(),
        penaltyLinesInstruction: instruction.trim(),
        completedLines: 0,
        penaltyLinesStatus: "pending",
        penaltyLinesCompletedAt: null,
        penaltyLinesCompletedBy: null,
        lastModifiedByUid: actor.actorUid,
      } : {
        hasPenaltyLines: false,
        totalLines: 0,
        penaltyLinesCount: 0,
        text: "",
        penaltyLinesInstruction: "",
        completedLines: 0,
        penaltyLinesStatus: "completed",
        penaltyLinesCompletedAt: fieldValue.serverTimestamp(),
        penaltyLinesCompletedBy: actor.actorUid,
        lastModifiedByUid: actor.actorUid,
      };
      await punishmentRef.update(patch);
      const saved = await punishmentRef.get();
      return {punishment: {id: saved.id, ...saved.data()}};
    } catch (error) {
      throw fail(error);
    }
  });

  return {
    recordPointAction,
    getPointActionStatus,
    recordHistoryEvent,
    setMemberDisplayName,
    completePenaltyLines,
    updatePenaltyLines,
  };
}

module.exports = {
  normalizePointAction,
  normalizeHistoryEvent,
  resolveActor,
  fingerprint,
  buildPointHistory,
  buildPenaltyLines,
  validatePhotoMetadata,
  createPointActionFunctions,
};
