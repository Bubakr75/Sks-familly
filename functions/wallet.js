"use strict";

const DOCUMENT_ID_PATTERN = /^[^/]{1,200}$/;
const MAX_WALLET_AMOUNT = 100000;
const MAX_REASON_LENGTH = 200;

function cleanWalletDocumentId(value, fieldName) {
  if (typeof value !== "string") {
    throw new Error(`INVALID_${fieldName.toUpperCase()}`);
  }

  const id = value.trim();
  if (
    !DOCUMENT_ID_PATTERN.test(id) ||
    /[\u0000-\u001f]/.test(id)
  ) {
    throw new Error(`INVALID_${fieldName.toUpperCase()}`);
  }
  return id;
}

function normalizeWalletOperation(data) {
  const familyId = cleanWalletDocumentId(
    data && data.familyId,
    "family_id"
  );
  const childId = cleanWalletDocumentId(
    data && data.childId,
    "child_id"
  );
  const operationId = cleanWalletDocumentId(
    data && data.operationId,
    "operation_id"
  );
  const type = data && data.type;
  const amount = data && data.amount;
  const reason =
    data && typeof data.reason === "string"
      ? data.reason.trim()
      : "";

  if (type !== "credit" && type !== "debit") {
    throw new Error("INVALID_OPERATION_TYPE");
  }
  if (
    !Number.isInteger(amount) ||
    amount < 1 ||
    amount > MAX_WALLET_AMOUNT
  ) {
    throw new Error("INVALID_AMOUNT");
  }
  if (
    reason.length < 1 ||
    reason.length > MAX_REASON_LENGTH ||
    /[\u0000-\u001f]/.test(reason)
  ) {
    throw new Error("INVALID_REASON");
  }

  return {
    familyId,
    childId,
    operationId,
    type,
    amount,
    reason,
  };
}

function isAuthorizedWalletParent({
  uid,
  family,
  member,
}) {
  if (!member || member.active !== true || member.uid !== uid) {
    return false;
  }
  if (member.role === "parent") return true;
  return member.role === "owner" && family.ownerUid === uid;
}

function buildWalletOperationData({
  operation,
  actorUid,
  balanceAfter,
  childPointsAfter,
  timestamp,
}) {
  const data = {
    childId: operation.childId,
    type: operation.type,
    amount: operation.amount,
    delta:
      operation.type === "credit"
        ? operation.amount
        : -operation.amount,
    reason: operation.reason,
    actorUid,
    balanceAfter,
    createdAt: timestamp,
    pointsKind: "behavior_points",
    pointsDebited: operation.type === "credit",
    pointsReturned: operation.type === "debit",
  };
  if (Number.isInteger(childPointsAfter)) {
    data.childPointsAfter = childPointsAfter;
  }
  return data;
}

function isMatchingWalletOperation({
  existing,
  operation,
  actorUid,
}) {
  return existing.actorUid === actorUid &&
    existing.childId === operation.childId &&
    existing.type === operation.type &&
    existing.amount === operation.amount &&
    existing.reason === operation.reason;
}

function calculateWalletBalance({
  currentBalance,
  type,
  amount,
}) {
  if (!Number.isInteger(currentBalance) || currentBalance < 0) {
    throw new Error("INVALID_WALLET_BALANCE");
  }
  const balance =
    type === "credit"
      ? currentBalance + amount
      : currentBalance - amount;
  if (balance < 0) throw new Error("INSUFFICIENT_BALANCE");
  return balance;
}

function calculateChildPointsAfterWalletCredit({
  currentChildPoints,
  type,
  amount,
}) {
  if (!Number.isInteger(currentChildPoints) || currentChildPoints < 0) {
    throw new Error("INVALID_CHILD_POINTS_BALANCE");
  }
  if (type === "credit" && currentChildPoints < amount) {
    throw new Error("INSUFFICIENT_CHILD_POINTS");
  }
  return type === "credit"
    ? currentChildPoints - amount
    : currentChildPoints + amount;
}

function normalizeWalletReversal(data) {
  return {
    familyId: cleanWalletDocumentId(data && data.familyId, "family_id"),
    childId: cleanWalletDocumentId(data && data.childId, "child_id"),
    operationId: cleanWalletDocumentId(
      data && data.operationId,
      "operation_id"
    ),
  };
}

function validateReversibleWalletOperation(operation, childId) {
  if (!operation ||
      operation.childId !== childId ||
      operation.type !== "credit" ||
      operation.pointsDebited !== true ||
      operation.pointsKind !== "behavior_points" ||
      !Number.isInteger(operation.amount) ||
      operation.amount < 1 ||
      operation.amount > MAX_WALLET_AMOUNT) {
    throw new Error("OPERATION_NOT_REVERSIBLE");
  }
  return operation.amount;
}

function createWalletFunctions({
  functions,
  admin,
  db,
}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  function toHttpsError(error) {
    if (error instanceof HttpsError) return error;

    const invalidErrors = new Set([
      "INVALID_FAMILY_ID",
      "INVALID_CHILD_ID",
      "INVALID_OPERATION_ID",
      "INVALID_OPERATION_TYPE",
      "INVALID_AMOUNT",
      "INVALID_REASON",
    ]);

    if (invalidErrors.has(error && error.message)) {
      return new HttpsError(
        "invalid-argument",
        "Les données de l'opération sont invalides."
      );
    }
    if (error && error.message === "INSUFFICIENT_BALANCE") {
      return new HttpsError(
        "failed-precondition",
        "Le solde de la cagnotte est insuffisant."
      );
    }
    if (error && error.message === "INSUFFICIENT_CHILD_POINTS") {
      return new HttpsError(
        "failed-precondition",
        "Le solde de points de l'enfant est insuffisant."
      );
    }
    if (error && error.message === "IDEMPOTENCY_CONFLICT") {
      return new HttpsError(
        "already-exists",
        "Cet identifiant d'opération est déjà utilisé."
      );
    }

    console.error("Wallet operation error:", error);
    return new HttpsError(
      "internal",
      "Impossible de modifier la cagnotte pour le moment."
    );
  }

  const adjustWallet = functions.https.onCall(
    async (data, context) => {
      try {
        if (!context.auth || !context.auth.uid) {
          throw new HttpsError(
            "unauthenticated",
            "Une authentification Firebase est requise."
          );
        }

        const actorUid = context.auth.uid;
        const operation = normalizeWalletOperation(data);
        const familyRef = db
          .collection("families")
          .doc(operation.familyId);
        const memberRef = familyRef
          .collection("members")
          .doc(actorUid);
        const childRef = familyRef
          .collection("children")
          .doc(operation.childId);
        const walletRef = familyRef
          .collection("wallets")
          .doc(operation.childId);
        const operationRef = walletRef
          .collection("operations")
          .doc(operation.operationId);
        const historyRef = familyRef
          .collection("history")
          .doc(`wallet_${operation.operationId}`);

        return await db.runTransaction(async (transaction) => {
          const [
            familySnapshot,
            memberSnapshot,
            childSnapshot,
            walletSnapshot,
            operationSnapshot,
          ] = await Promise.all([
            transaction.get(familyRef),
            transaction.get(memberRef),
            transaction.get(childRef),
            transaction.get(walletRef),
            transaction.get(operationRef),
          ]);

          if (!familySnapshot.exists) {
            throw new HttpsError("not-found", "Famille introuvable.");
          }
          if (
            !isAuthorizedWalletParent({
              uid: actorUid,
              family: familySnapshot.data(),
              member: memberSnapshot.exists
                ? memberSnapshot.data()
                : null,
            })
          ) {
            throw new HttpsError(
              "permission-denied",
              "Seul un parent autorisé peut modifier la cagnotte."
            );
          }
          if (!childSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "Cet enfant n'appartient pas à la famille."
            );
          }

          if (operationSnapshot.exists) {
            const existing = operationSnapshot.data();
            if (isMatchingWalletOperation({
              existing,
              operation,
              actorUid,
            })) {
              return {
                operationId: operation.operationId,
                balance: existing.balanceAfter,
                idempotent: true,
              };
            }
            throw new Error("IDEMPOTENCY_CONFLICT");
          }

          const currentBalance = walletSnapshot.exists
            ? walletSnapshot.data().balance
            : 0;
          const balance = calculateWalletBalance({
            currentBalance,
            type: operation.type,
            amount: operation.amount,
          });
          const childData = childSnapshot.data() || {};
          const childPointsAfter = calculateChildPointsAfterWalletCredit({
            currentChildPoints: childData.points,
            type: operation.type,
            amount: operation.amount,
          });

          const timestamp = fieldValue.serverTimestamp();
          const walletData = {
            childId: operation.childId,
            balance,
            updatedAt: timestamp,
          };
          if (!walletSnapshot.exists) {
            walletData.createdAt = timestamp;
          }

          transaction.set(
            walletRef,
            walletData,
            {merge: true}
          );
          transaction.update(childRef, {points: childPointsAfter});
          transaction.create(
            operationRef,
            buildWalletOperationData({
              operation,
              actorUid,
              balanceAfter: balance,
              childPointsAfter,
              timestamp,
            })
          );
          if (operation.type === "debit") {
            transaction.create(historyRef, {
              childId: operation.childId,
              points: operation.amount,
              reason: `Restitution cagnotte : ${operation.reason}`,
              category: "wallet_withdrawal",
              isBonus: true,
              date: timestamp,
              createdAt: timestamp,
              actionByUid: actorUid,
              walletOperationId: operation.operationId,
            });
          }

          return {
            operationId: operation.operationId,
            balance,
            childPoints: childPointsAfter,
            idempotent: false,
          };
        });
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  const reverseWalletOperation = functions.https.onCall(
    async (data, context) => {
      try {
        if (!context.auth || !context.auth.uid) {
          throw new HttpsError(
            "unauthenticated",
            "Une authentification Firebase est requise."
          );
        }
        const actorUid = context.auth.uid;
        const reversal = normalizeWalletReversal(data);
        const familyRef = db.collection("families").doc(reversal.familyId);
        const memberRef = familyRef.collection("members").doc(actorUid);
        const childRef = familyRef.collection("children").doc(reversal.childId);
        const walletRef = familyRef.collection("wallets").doc(reversal.childId);
        const operationRef = walletRef
          .collection("operations")
          .doc(reversal.operationId);
        const reversalId = `reversal_${reversal.operationId}`;
        const reversalRef = walletRef.collection("operations").doc(reversalId);
        const historyRef = familyRef.collection("history").doc(reversalId);

        return await db.runTransaction(async (transaction) => {
          const [familySnap, memberSnap, childSnap, walletSnap,
            operationSnap, reversalSnap] = await Promise.all([
            transaction.get(familyRef),
            transaction.get(memberRef),
            transaction.get(childRef),
            transaction.get(walletRef),
            transaction.get(operationRef),
            transaction.get(reversalRef),
          ]);
          if (!familySnap.exists || !childSnap.exists || !walletSnap.exists) {
            throw new HttpsError("not-found", "Famille, enfant ou cagnotte introuvable.");
          }
          if (!isAuthorizedWalletParent({
            uid: actorUid,
            family: familySnap.data(),
            member: memberSnap.exists ? memberSnap.data() : null,
          })) {
            throw new HttpsError(
              "permission-denied",
              "Seul un parent autorisé peut annuler cette opération."
            );
          }
          if (!operationSnap.exists) {
            throw new HttpsError("not-found", "Opération introuvable.");
          }
          if (reversalSnap.exists) {
            const existing = reversalSnap.data();
            return {
              operationId: reversal.operationId,
              reversalTransactionId: reversalId,
              balance: existing.balanceAfter,
              childPoints: existing.childPointsAfter,
              idempotent: true,
            };
          }
          const original = operationSnap.data();
          if (original.reversedAt || original.status === "reversed") {
            throw new Error("ALREADY_REVERSED");
          }
          const amount = validateReversibleWalletOperation(
            original,
            reversal.childId
          );
          const wallet = walletSnap.data() || {};
          const child = childSnap.data() || {};
          if (!Number.isInteger(wallet.balance) || wallet.balance < amount) {
            throw new Error("INSUFFICIENT_BALANCE");
          }
          if (!Number.isInteger(child.points) || child.points < 0) {
            throw new Error("INVALID_CHILD_POINTS_BALANCE");
          }
          const balanceAfter = wallet.balance - amount;
          const childPointsAfter = child.points + amount;
          const timestamp = fieldValue.serverTimestamp();
          transaction.update(walletRef, {balance: balanceAfter, updatedAt: timestamp});
          transaction.update(childRef, {points: childPointsAfter});
          transaction.update(operationRef, {
            status: "reversed",
            reversedAt: timestamp,
            reversedBy: actorUid,
            reversalTransactionId: reversalId,
          });
          transaction.create(reversalRef, {
            childId: reversal.childId,
            type: "reversal",
            amount,
            delta: -amount,
            reason: `Annulation : ${original.reason}`,
            actorUid,
            balanceAfter,
            childPointsAfter,
            pointsKind: "behavior_points",
            originalOperationId: reversal.operationId,
            createdAt: timestamp,
          });
          transaction.create(historyRef, {
            childId: reversal.childId,
            points: amount,
            reason: `Remboursement cagnotte : ${original.reason}`,
            category: "wallet_reversal",
            isBonus: true,
            date: timestamp,
            createdAt: timestamp,
            actionByUid: actorUid,
            walletOperationId: reversal.operationId,
            reversalTransactionId: reversalId,
          });
          return {
            operationId: reversal.operationId,
            reversalTransactionId: reversalId,
            balance: balanceAfter,
            childPoints: childPointsAfter,
            idempotent: false,
          };
        });
      } catch (error) {
        if (error && error.message === "OPERATION_NOT_REVERSIBLE") {
          throw new HttpsError(
            "failed-precondition",
            "Cette opération n’a pas débité les points de l’enfant."
          );
        }
        if (error && error.message === "ALREADY_REVERSED") {
          throw new HttpsError("already-exists", "Cette opération est déjà annulée.");
        }
        throw toHttpsError(error);
      }
    }
  );

  return {adjustWallet, reverseWalletOperation};
}

module.exports = {
  MAX_WALLET_AMOUNT,
  normalizeWalletOperation,
  isAuthorizedWalletParent,
  buildWalletOperationData,
  isMatchingWalletOperation,
  calculateWalletBalance,
  calculateChildPointsAfterWalletCredit,
  normalizeWalletReversal,
  validateReversibleWalletOperation,
  createWalletFunctions,
};
