"use strict";

const crypto = require("node:crypto");

const ID_PATTERN = /^[^/\u0000-\u001f]{1,200}$/;
const OPERATIONS = new Set([
  "purchase_reward",
  "tribunal_vote",
  "tribunal_remove_vote",
  "trade_create",
  "trade_accept",
  "trade_reject",
  "trade_cancel",
  "trade_service_done",
  "screen_start",
  "screen_stop",
]);
const VOTES = new Set(["guilty", "innocent"]);

function cleanId(value, name) {
  if (typeof value !== "string" || !ID_PATTERN.test(value.trim())) {
    throw new Error(`INVALID_${name.toUpperCase()}`);
  }
  return value.trim();
}

function normalizeSecureOperation(data) {
  const operation = data && data.operation;
  if (!OPERATIONS.has(operation)) throw new Error("INVALID_OPERATION");
  const normalized = {
    familyId: cleanId(data.familyId, "family_id"),
    operationId: cleanId(data.operationId, "operation_id"),
    operation,
  };
  for (const key of ["childId", "rewardId", "caseId", "tradeId", "toChildId"]) {
    if (data[key] !== undefined) normalized[key] = cleanId(data[key], key);
  }
  if (data.vote !== undefined) {
    if (!VOTES.has(data.vote)) throw new Error("INVALID_VOTE");
    normalized.vote = data.vote;
  }
  if (data.minutes !== undefined) {
    if (!Number.isInteger(data.minutes) || data.minutes < 1 || data.minutes > 480) {
      throw new Error("INVALID_MINUTES");
    }
    normalized.minutes = data.minutes;
  }
  if (data.immunityLines !== undefined) {
    if (!Number.isInteger(data.immunityLines) ||
        data.immunityLines < 1 || data.immunityLines > 100) {
      throw new Error("INVALID_IMMUNITY_LINES");
    }
    normalized.immunityLines = data.immunityLines;
  }
  if (data.description !== undefined) {
    if (typeof data.description !== "string" ||
        data.description.trim().length < 1 ||
        data.description.trim().length > 300 ||
        /[\u0000-\u001f]/.test(data.description)) {
      throw new Error("INVALID_DESCRIPTION");
    }
    normalized.description = data.description.trim();
  }
  return normalized;
}

function memberRole({uid, family, member}) {
  if (!member || member.active !== true || member.uid !== uid) return null;
  if (member.role === "owner") {
    return family && family.ownerUid === uid ? "parent" : null;
  }
  if (member.role === "parent") return "parent";
  if (member.role === "child" &&
      typeof member.childId === "string" &&
      ID_PATTERN.test(member.childId)) return "child";
  return null;
}

function authorizeChildTarget({role, member, childId}) {
  return role === "parent" ||
    (role === "child" && member.childId === childId);
}

function operationFingerprint(operation, uid) {
  return crypto
    .createHash("sha256")
    .update(JSON.stringify({...operation, uid}))
    .digest("hex");
}

function isMatchingReplay(existing, fingerprint) {
  return existing && existing.fingerprint === fingerprint;
}

function applyTradeTransition(status, operation) {
  const transitions = {
    trade_accept: ["pending", "accepted"],
    trade_reject: ["pending", "rejected"],
    trade_cancel: ["pending", "cancelled"],
    trade_service_done: ["accepted", "service_done"],
  };
  const transition = transitions[operation];
  if (!transition || transition[0] !== status) {
    throw new Error("INVALID_TRADE_TRANSITION");
  }
  return transition[1];
}

function createSecureChildOperationFunctions({functions, admin, db}) {
  const HttpsError = functions.https.HttpsError;
  const serverTimestamp = admin.firestore.FieldValue.serverTimestamp;

  function fail(error) {
    if (error instanceof HttpsError) return error;
    const invalid = typeof error.message === "string" &&
      (error.message.startsWith("INVALID_") ||
       error.message === "IDEMPOTENCY_CONFLICT");
    if (invalid) {
      return new HttpsError(
        error.message === "IDEMPOTENCY_CONFLICT"
          ? "already-exists"
          : "invalid-argument",
        "Opération refusée : données ou transition invalides."
      );
    }
    console.error("Secure family operation error:", error);
    return new HttpsError("internal", "L'opération n'a pas pu être effectuée.");
  }

  const performFamilyOperation = functions.https.onCall(async (data, context) => {
    try {
      if (!context.auth || !context.auth.uid) {
        throw new HttpsError("unauthenticated", "Authentification requise.");
      }
      const uid = context.auth.uid;
      const op = normalizeSecureOperation(data);
      const familyRef = db.collection("families").doc(op.familyId);
      const memberRef = familyRef.collection("members").doc(uid);
      const logRef = familyRef.collection("_operations").doc(op.operationId);
      const fingerprint = operationFingerprint(op, uid);

      return await db.runTransaction(async (tx) => {
        const [familySnap, memberSnap, logSnap] = await Promise.all([
          tx.get(familyRef),
          tx.get(memberRef),
          tx.get(logRef),
        ]);
        if (!familySnap.exists) throw new HttpsError("not-found", "Famille introuvable.");
        const member = memberSnap.exists ? memberSnap.data() : null;
        const role = memberRole({uid, family: familySnap.data(), member});
        if (!role) throw new HttpsError("permission-denied", "Membre actif requis.");
        if (logSnap.exists) {
          if (!isMatchingReplay(logSnap.data(), fingerprint)) {
            throw new Error("IDEMPOTENCY_CONFLICT");
          }
          return {...logSnap.data().result, idempotent: true};
        }

        let result;
        if (op.operation === "purchase_reward") {
          if (!op.childId || !op.rewardId ||
              !authorizeChildTarget({role, member, childId: op.childId})) {
            throw new HttpsError("permission-denied", "Achat non autorisé.");
          }
          const childRef = familyRef.collection("children").doc(op.childId);
          const rewardRef = familyRef.collection("rewards").doc(op.rewardId);
          const purchaseRef = familyRef.collection("purchases").doc(op.operationId);
          const [childSnap, rewardSnap] = await Promise.all([
            tx.get(childRef), tx.get(rewardRef),
          ]);
          if (!childSnap.exists || !rewardSnap.exists) {
            throw new HttpsError("not-found", "Enfant ou récompense introuvable.");
          }
          const child = childSnap.data();
          const reward = rewardSnap.data();
          if (!Number.isInteger(child.points) ||
              !Number.isInteger(reward.cost) ||
              reward.cost < 0 || reward.cost > 100000 ||
              reward.isDeleted === true) {
            throw new Error("INVALID_PURCHASE_STATE");
          }
          if (child.points < reward.cost) {
            throw new HttpsError("failed-precondition", "Points insuffisants.");
          }
          const purchase = {
            id: op.operationId,
            rewardId: op.rewardId,
            childId: op.childId,
            childName: typeof child.name === "string" ? child.name.slice(0, 120) : "",
            title: typeof reward.title === "string" ? reward.title.slice(0, 200) : "",
            icon: typeof reward.icon === "string" ? reward.icon.slice(0, 16) : "",
            cost: reward.cost,
            originalCost: reward.cost,
            status: "pending",
            date: new Date().toISOString(),
            actorUid: uid,
          };
          tx.update(childRef, {points: child.points - reward.cost});
          tx.create(purchaseRef, purchase);
          result = {purchase, points: child.points - reward.cost};
        } else if (op.operation.startsWith("tribunal_")) {
          if (role !== "child" || !op.caseId) {
            throw new HttpsError("permission-denied", "Vote enfant requis.");
          }
          const caseRef = familyRef.collection("tribunal").doc(op.caseId);
          const caseSnap = await tx.get(caseRef);
          if (!caseSnap.exists) throw new HttpsError("not-found", "Affaire introuvable.");
          const tribunal = caseSnap.data();
          const childId = member.childId;
          if (tribunal.votingEnabled !== true ||
              !["inProgress", "deliberation"].includes(tribunal.status) ||
              tribunal.plaintiffId === childId || tribunal.accusedId === childId) {
            throw new HttpsError("failed-precondition", "Vote impossible.");
          }
          const votes = Array.isArray(tribunal.votes) ? [...tribunal.votes] : [];
          const index = votes.findIndex((vote) => vote.childId === childId);
          if (op.operation === "tribunal_remove_vote") {
            if (index >= 0) votes.splice(index, 1);
          } else {
            if (!op.vote) throw new Error("INVALID_VOTE");
            const vote = {
              childId,
              vote: op.vote,
              votedAt: new Date().toISOString(),
              pointsAwarded: 0,
            };
            if (index >= 0) votes[index] = vote;
            else votes.push(vote);
          }
          if (votes.length > 100) throw new Error("INVALID_VOTE_COUNT");
          tx.update(caseRef, {votes});
          result = {caseId: op.caseId, votes};
        } else if (op.operation.startsWith("trade_")) {
          if (op.operation === "trade_create") {
            if (!op.childId || !op.toChildId || !op.immunityLines || !op.description ||
                op.childId === op.toChildId ||
                !authorizeChildTarget({role, member, childId: op.childId})) {
              throw new HttpsError("permission-denied", "Échange non autorisé.");
            }
            const fromRef = familyRef.collection("children").doc(op.childId);
            const toRef = familyRef.collection("children").doc(op.toChildId);
            const tradeRef = familyRef.collection("trades").doc(op.operationId);
            const [fromSnap, toSnap] = await Promise.all([tx.get(fromRef), tx.get(toRef)]);
            if (!fromSnap.exists || !toSnap.exists) {
              throw new HttpsError("not-found", "Enfant introuvable.");
            }
            const trade = {
              id: op.operationId,
              fromChildId: op.childId,
              toChildId: op.toChildId,
              immunityLines: op.immunityLines,
              serviceDescription: op.description,
              status: "pending",
              createdAt: new Date().toISOString(),
              acceptedAt: null,
              completedAt: null,
              parentValidatorNote: null,
              actorUid: uid,
            };
            tx.create(tradeRef, trade);
            result = {trade};
          } else {
            if (!op.tradeId) throw new Error("INVALID_TRADE_ID");
            const tradeRef = familyRef.collection("trades").doc(op.tradeId);
            const tradeSnap = await tx.get(tradeRef);
            if (!tradeSnap.exists) throw new HttpsError("not-found", "Échange introuvable.");
            const trade = tradeSnap.data();
            const expectedChild = ["trade_accept", "trade_reject"].includes(op.operation)
              ? trade.toChildId : trade.fromChildId;
            if (!authorizeChildTarget({role, member, childId: expectedChild})) {
              throw new HttpsError("permission-denied", "Transition non autorisée.");
            }
            const status = applyTradeTransition(trade.status, op.operation);
            const patch = {status};
            if (status === "accepted") patch.acceptedAt = new Date().toISOString();
            tx.update(tradeRef, patch);
            result = {tradeId: op.tradeId, ...patch};
          }
        } else {
          if (!op.childId ||
              !authorizeChildTarget({role, member, childId: op.childId})) {
            throw new HttpsError("permission-denied", "Compte non autorisé.");
          }
          const accountRef = familyRef.collection("screen_time_accounts").doc(op.childId);
          const accountSnap = await tx.get(accountRef);
          const account = accountSnap.exists ? accountSnap.data() : {
            childId: op.childId, balanceMinutes: 0, totalEarned: 0,
            totalUsed: 0, sessionStart: null, sessionMinutes: 0,
            appliedOvertimeTranches: 0, history: [],
          };
          if (!Number.isInteger(account.balanceMinutes) || account.balanceMinutes < 0) {
            throw new Error("INVALID_SCREEN_ACCOUNT");
          }
          if (op.operation === "screen_start") {
            if (!op.minutes || account.sessionStart != null ||
                account.balanceMinutes < op.minutes) {
              throw new HttpsError("failed-precondition", "Session impossible.");
            }
            Object.assign(account, {
              balanceMinutes: account.balanceMinutes - op.minutes,
              sessionStart: new Date().toISOString(),
              sessionMinutes: op.minutes,
              appliedOvertimeTranches: 0,
            });
          } else {
            if (typeof account.sessionStart !== "string" ||
                !Number.isInteger(account.sessionMinutes)) {
              throw new HttpsError("failed-precondition", "Aucune session active.");
            }
            const elapsed = Math.max(0, Math.floor(
              (Date.now() - Date.parse(account.sessionStart)) / 60000
            ));
            const used = Math.min(account.sessionMinutes, elapsed);
            const remaining = account.sessionMinutes - used;
            account.balanceMinutes += remaining;
            account.totalUsed = (Number.isInteger(account.totalUsed) ? account.totalUsed : 0) + used;
            account.sessionStart = null;
            account.sessionMinutes = 0;
            account.appliedOvertimeTranches = 0;
          }
          account.history = Array.isArray(account.history)
            ? account.history.slice(0, 99) : [];
          if (accountSnap.exists) tx.set(accountRef, account);
          else tx.create(accountRef, account);
          result = {account};
        }

        tx.create(logRef, {
          fingerprint,
          operation: op.operation,
          actorUid: uid,
          createdAt: serverTimestamp(),
          result,
        });
        return {...result, idempotent: false};
      });
    } catch (error) {
      throw fail(error);
    }
  });

  return {performFamilyOperation};
}

module.exports = {
  OPERATIONS,
  normalizeSecureOperation,
  memberRole,
  authorizeChildTarget,
  operationFingerprint,
  isMatchingReplay,
  applyTradeTransition,
  createSecureChildOperationFunctions,
};
