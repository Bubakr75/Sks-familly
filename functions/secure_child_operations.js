"use strict";

const crypto = require("node:crypto");

const ID_PATTERN = /^[^/\u0000-\u001f]{1,200}$/;
const OPERATIONS = new Set([
  "purchase_reward",
  "purchase_approve",
  "purchase_reject",
  "sale_set",
  "sale_stop",
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
  for (const key of ["childId", "rewardId", "requestId", "caseId", "tradeId", "toChildId"]) {
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
  if (data.percent !== undefined) {
    if (!Number.isInteger(data.percent) || data.percent < 1 || data.percent > 90) {
      throw new Error("INVALID_PERCENT");
    }
    normalized.percent = data.percent;
  }
  if (data.durationHours !== undefined) {
    if (!Number.isInteger(data.durationHours) || data.durationHours < 1 || data.durationHours > 720) {
      throw new Error("INVALID_DURATION_HOURS");
    }
    normalized.durationHours = data.durationHours;
  }
  if (data.label !== undefined) {
    if (typeof data.label !== "string" || data.label.trim().length > 80) {
      throw new Error("INVALID_LABEL");
    }
    normalized.label = data.label.trim();
  }
  if (data.reason !== undefined) {
    if (typeof data.reason !== "string" || data.reason.trim().length > 300) {
      throw new Error("INVALID_REASON");
    }
    normalized.reason = data.reason.trim();
  }
  return normalized;
}

function memberRole({uid, family, member, authToken = {}}) {
  if (!member || member.active !== true || member.uid !== uid) return null;
  if (member.role === "owner") {
    return family && family.ownerUid === uid ? "parent" : null;
  }
  if (member.role === "parent") return "parent";
  if ((member.role === "manager" || member.role === "familyAdmin") &&
      authToken.email_verified === true &&
      authToken.firebase && authToken.firebase.sign_in_provider !== "anonymous") {
    return "parent";
  }
  if (member.role === "child" &&
      typeof member.childId === "string" &&
      ID_PATTERN.test(member.childId)) return "child";
  return null;
}

function screenTimeMinutes(reward) {
  const title = typeof reward.title === "string" ? reward.title.toLowerCase() : "";
  const isScreenTime = title.includes("ecran") || title.includes("écran") ||
    title.includes("min") || reward.icon === "🎮";
  if (!isScreenTime) return 0;
  const match = title.match(/(\d+)/);
  return Math.min(480, Math.max(1, match ? Number.parseInt(match[1], 10) : 15));
}

function buildPurchaseRequest({operationId, childId, childName, reward, cost, salePercent = 0, actorUid, now}) {
  const title = typeof reward.title === "string" ? reward.title.slice(0, 200) : "";
  const icon = typeof reward.icon === "string" ? reward.icon.slice(0, 16) : "";
  return {
    id: operationId,
    type: "boutique",
    childId,
    requestedBy: childName,
    text: `🛒 ${childName || "Un enfant"} achète "${title || "une récompense"}" (${cost} pts)`,
    amount: cost,
    status: "pending",
    createdAt: now,
    extra: {
      purchaseId: operationId,
      rewardId: reward.id || "",
      rewardTitle: title,
      icon,
      originalCost: reward.cost,
      salePrice: cost,
      onSale: salePercent > 0,
    },
    readBy: [],
    lastModifiedBy: actorUid,
  };
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
        const role = memberRole({uid, family: familySnap.data(), member,
          authToken: context.auth.token || {}});
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
          const requestRef = familyRef.collection("requests").doc(op.operationId);
          const accountRef = familyRef.collection("screen_time_accounts").doc(op.childId);
          const saleRef = familyRef.collection("settings").doc("shop");
          const [childSnap, rewardSnap, saleSnap, accountSnap] = await Promise.all([
            tx.get(childRef), tx.get(rewardRef), tx.get(saleRef), tx.get(accountRef),
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
          const sale = saleSnap.exists ? saleSnap.data() : {};
          const saleActive = Number.isInteger(sale.percent) && sale.percent >= 1 &&
            sale.percent <= 90 && typeof sale.endAt === "string" && sale.endAt > new Date().toISOString();
          const cost = saleActive ? Math.max(1, Math.round(reward.cost * (100 - sale.percent) / 100)) : reward.cost;
          if (child.points < cost) {
            throw new HttpsError("failed-precondition", "Points insuffisants.");
          }
          const now = new Date().toISOString();
          const childName = typeof child.name === "string" ? child.name.slice(0, 120) : "";
          const minutes = screenTimeMinutes(reward);
          const purchase = {
            id: op.operationId,
            rewardId: op.rewardId,
            childId: op.childId,
            childName,
            title: typeof reward.title === "string" ? reward.title.slice(0, 200) : "",
            icon: typeof reward.icon === "string" ? reward.icon.slice(0, 16) : "",
            cost,
            salePercent: saleActive ? sale.percent : 0,
            originalCost: reward.cost,
            status: "pending",
            date: now,
            actorUid: uid,
            screenTimeMinutes: minutes,
          };
          const request = buildPurchaseRequest({
            operationId: op.operationId,
            childId: op.childId,
            childName,
            reward: {...reward, id: op.rewardId},
            cost,
            actorUid: uid,
            now,
          });
          tx.update(childRef, {points: child.points - cost});
          tx.create(purchaseRef, purchase);
          tx.create(requestRef, request);
          const historyRef = familyRef.collection("history").doc(`${op.operationId}_purchase`);
          tx.create(historyRef, {
            id: historyRef.id, childId: op.childId, points: cost,
            reason: `Achat boutique : ${purchase.title}`, category: "boutique",
            date: now, isBonus: false, actionBy: childName, actorUid: uid,
          });
          if (minutes > 0) {
            const account = accountSnap.exists ? accountSnap.data() : {};
            const balance = Number.isInteger(account.balanceMinutes) ? account.balanceMinutes : 0;
            tx.set(accountRef, {...account, childId: op.childId,
              balanceMinutes: balance + minutes, lastUpdated: now}, {merge: true});
          }
          result = {purchase, request, points: child.points - cost, minutes};
        } else if (op.operation === "purchase_approve" || op.operation === "purchase_reject") {
          if (role !== "parent" || !op.requestId) {
            throw new HttpsError("permission-denied", "Validation parent requise.");
          }
          const requestRef = familyRef.collection("requests").doc(op.requestId);
          const purchaseRef = familyRef.collection("purchases").doc(op.requestId);
          const [requestSnap, purchaseSnap] = await Promise.all([tx.get(requestRef), tx.get(purchaseRef)]);
          if (!requestSnap.exists || !purchaseSnap.exists) throw new HttpsError("not-found", "Achat introuvable.");
          const request = requestSnap.data();
          const purchase = purchaseSnap.data();
          if (request.type !== "boutique" || request.status !== "pending" || purchase.status !== "pending") {
            throw new Error("INVALID_PURCHASE_STATE");
          }
          const status = op.operation === "purchase_approve" ? "approved" : "rejected";
          const now = new Date().toISOString();
          let childRef;
          let childSnap;
          let accountRef;
          let accountSnap;
          if (status === "rejected") {
            childRef = familyRef.collection("children").doc(purchase.childId);
            childSnap = await tx.get(childRef);
            if (!childSnap.exists || !Number.isInteger(childSnap.data().points) || !Number.isInteger(purchase.cost)) {
              throw new Error("INVALID_PURCHASE_STATE");
            }
            if (Number.isInteger(purchase.screenTimeMinutes) && purchase.screenTimeMinutes > 0) {
              accountRef = familyRef.collection("screen_time_accounts").doc(purchase.childId);
              accountSnap = await tx.get(accountRef);
            }
          }
          tx.update(purchaseRef, {status, reviewedAt: now, reviewedBy: uid});
          tx.delete(requestRef);
          if (status === "rejected") {
            tx.update(childRef, {points: childSnap.data().points + purchase.cost});
            if (accountRef && accountSnap && accountSnap.exists) {
              const account = accountSnap.data();
              const balance = Number.isInteger(account.balanceMinutes) ? account.balanceMinutes : 0;
              tx.update(accountRef, {
                balanceMinutes: Math.max(0, balance - purchase.screenTimeMinutes),
                lastUpdated: now,
              });
            }
            const refundRef = familyRef.collection("history").doc(`${op.requestId}_refund`);
            tx.create(refundRef, {id: refundRef.id, childId: purchase.childId, points: purchase.cost,
              reason: `Achat annulé : ${purchase.title || "récompense"}`, category: "boutique",
              date: now, isBonus: true, actionBy: "Parent", actorUid: uid});
          }
          result = {purchaseId: op.requestId, status};
        } else if (op.operation === "sale_set" || op.operation === "sale_stop") {
          if (role !== "parent") throw new HttpsError("permission-denied", "Action parent requise.");
          const saleRef = familyRef.collection("settings").doc("shop");
          if (op.operation === "sale_stop") {
            tx.set(saleRef, {percent: 0, endAt: null, label: "", updatedBy: uid});
            result = {percent: 0};
          } else {
            if (!op.percent || !op.durationHours) throw new Error("INVALID_SALE");
            const endAt = new Date(Date.now() + op.durationHours * 3600000).toISOString();
            tx.set(saleRef, {percent: op.percent, endAt, label: op.label || "Soldes", updatedBy: uid});
            result = {percent: op.percent, endAt};
          }
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
            const immunitiesQuery = familyRef.collection("immunities")
              .where("childId", "==", op.childId);
            const [fromSnap, toSnap, immunitiesSnap] = await Promise.all([
              tx.get(fromRef), tx.get(toRef), tx.get(immunitiesQuery),
            ]);
            if (!fromSnap.exists || !toSnap.exists) {
              throw new HttpsError("not-found", "Enfant introuvable.");
            }
            const availableLines = immunitiesSnap.docs.reduce((total, doc) => {
              const immunity = doc.data();
              const lines = Number.isInteger(immunity.lines) ? immunity.lines : 0;
              const used = Number.isInteger(immunity.usedLines) ? immunity.usedLines : 0;
              return total + Math.max(0, lines - used);
            }, 0);
            if (availableLines < op.immunityLines) {
              throw new HttpsError(
                "failed-precondition",
                "Lignes d'immunité insuffisantes."
              );
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
          const childRef = familyRef.collection("children").doc(op.childId);
          const [accountSnap, childSnap] = await Promise.all([
            tx.get(accountRef), tx.get(childRef),
          ]);
          if (!childSnap.exists) {
            throw new HttpsError("not-found", "Enfant introuvable.");
          }
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
  buildPurchaseRequest,
  createSecureChildOperationFunctions,
};
