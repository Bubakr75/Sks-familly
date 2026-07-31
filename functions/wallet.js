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
  if (type !== "credit") return currentChildPoints;
  if (!Number.isInteger(currentChildPoints) || currentChildPoints < 0) {
    throw new Error("INVALID_CHILD_POINTS_BALANCE");
  }
  if (currentChildPoints < amount) {
    throw new Error("INSUFFICIENT_CHILD_POINTS");
  }
  return currentChildPoints - amount;
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
          if (operation.type === "credit") {
            transaction.update(childRef, {points: childPointsAfter});
          }
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

  return {adjustWallet};
}

module.exports = {
  MAX_WALLET_AMOUNT,
  normalizeWalletOperation,
  isAuthorizedWalletParent,
  buildWalletOperationData,
  isMatchingWalletOperation,
  calculateWalletBalance,
  calculateChildPointsAfterWalletCredit,
  createWalletFunctions,
};
