"use strict";

const crypto = require("crypto");
const {
  requireAuthenticatedUid,
  isAuthenticatedFamilyOwner,
  applyFamilyOwnerRepair,
} = require("./family_owner_authorization");

const FAMILY_CODE_PATTERN = /^[A-Z0-9]{4,10}$/;
const DOCUMENT_ID_PATTERN = /^[^/]{1,200}$/;
const RANDOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function normalizeManagedFamilyCode(value) {
  if (typeof value !== "string") {
    throw new Error("INVALID_FAMILY_CODE");
  }

  const code = value.trim().toUpperCase();

  if (!FAMILY_CODE_PATTERN.test(code)) {
    throw new Error("INVALID_FAMILY_CODE");
  }

  return code;
}

function cleanManagedDocumentId(value) {
  if (typeof value !== "string") {
    throw new Error("INVALID_DOCUMENT_ID");
  }

  const id = value.trim();

  if (
    !DOCUMENT_ID_PATTERN.test(id) ||
    /[\u0000-\u001f]/.test(id)
  ) {
    throw new Error("INVALID_DOCUMENT_ID");
  }

  return id;
}

function generateFamilyCode() {
  let result = "";

  for (let index = 0; index < 6; index += 1) {
    result += RANDOM_CODE_CHARS[
      crypto.randomInt(0, RANDOM_CODE_CHARS.length)
    ];
  }

  return result;
}

function buildManagedFamilyData({
  code,
  ownerUid,
  createdAt,
}) {
  return {
    code,
    createdAt,
    memberCount: 1,
    ownerUid,
    schemaVersion: 2,
    migrationStatus: "native",
  };
}

function buildManagedOwnerData({
  ownerUid,
  createdAt,
}) {
  return {
    uid: ownerUid,
    role: "owner",
    childId: null,
    active: true,
    createdAt,
    approvedBy: ownerUid,
    approvedAt: createdAt,
  };
}

function buildFamilyCodeIndexData({
  familyId,
  code,
  ownerUid,
  timestamp,
}) {
  return {
    familyId,
    code,
    ownerUid,
    createdAt: timestamp,
    updatedAt: timestamp,
  };
}

function createFamilyManagementFunctions({
  functions,
  admin,
  db,
}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  function requireAuth(context) {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Une authentification Firebase est requise."
      );
    }

    return context.auth.uid;
  }

  function toHttpsError(error) {
    if (error instanceof HttpsError) return error;

    switch (error && error.message) {
      case "INVALID_FAMILY_CODE":
        return new HttpsError(
          "invalid-argument",
          "Le code famille doit contenir entre 4 et 10 lettres ou chiffres."
        );
      case "INVALID_DOCUMENT_ID":
        return new HttpsError(
          "invalid-argument",
          "Identifiant de famille invalide."
        );
      case "FAMILY_CODE_TAKEN":
        return new HttpsError(
          "already-exists",
          "Ce code famille est déjà utilisé."
        );
      case "FAMILY_ID_TAKEN":
        return new HttpsError(
          "already-exists",
          "Cette création de famille existe déjà."
        );
      case "FAMILY_NOT_FOUND":
        return new HttpsError(
          "not-found",
          "Famille introuvable."
        );
      case "OWNER_REQUIRED":
        return new HttpsError(
          "permission-denied",
          "Seul le propriétaire peut modifier le code famille."
        );
      default:
        console.error("Family management error:", error);
        return new HttpsError(
          "internal",
          "Impossible de gérer la famille pour le moment."
        );
    }
  }

  async function createWithCode({
    ownerUid,
    familyId,
    code,
  }) {
    const familyRef = db.collection("families").doc(familyId);
    const ownerRef = familyRef.collection("members").doc(ownerUid);
    const codeRef = db.collection("family_codes").doc(code);

    return db.runTransaction(async (transaction) => {
      const familySnapshot = await transaction.get(familyRef);

      if (familySnapshot.exists) {
        const existingFamily = familySnapshot.data();

        if (
          existingFamily.ownerUid === ownerUid &&
          typeof existingFamily.code === "string"
        ) {
          return {
            familyId,
            code: existingFamily.code,
            alreadyCreated: true,
          };
        }

        throw new Error("FAMILY_ID_TAKEN");
      }

      const codeSnapshot = await transaction.get(codeRef);

      if (codeSnapshot.exists) {
        throw new Error("FAMILY_CODE_TAKEN");
      }

      // Compatibilité avec les familles créées avant family_codes.
      const existingCodeQuery = db
        .collection("families")
        .where("code", "==", code)
        .limit(1);

      const existingCodeSnapshot = await transaction.get(
        existingCodeQuery
      );

      if (!existingCodeSnapshot.empty) {
        throw new Error("FAMILY_CODE_TAKEN");
      }

      const timestamp = fieldValue.serverTimestamp();

      transaction.create(
        familyRef,
        buildManagedFamilyData({
          code,
          ownerUid,
          createdAt: timestamp,
        })
      );

      transaction.create(
        ownerRef,
        buildManagedOwnerData({
          ownerUid,
          createdAt: timestamp,
        })
      );

      transaction.create(
        codeRef,
        buildFamilyCodeIndexData({
          familyId,
          code,
          ownerUid,
          timestamp,
        })
      );

      return {
        familyId,
        code,
        alreadyCreated: false,
      };
    });
  }

  const createFamily = functions.https.onCall(
    async (data, context) => {
      try {
        const ownerUid = requireAuth(context);
        const familyId = cleanManagedDocumentId(
          data && data.familyId
        );

        const rawCustomCode =
          data && typeof data.customCode === "string"
            ? data.customCode.trim()
            : "";

        if (rawCustomCode) {
          const customCode = normalizeManagedFamilyCode(
            rawCustomCode
          );

          return await createWithCode({
            ownerUid,
            familyId,
            code: customCode,
          });
        }

        for (let attempt = 0; attempt < 12; attempt += 1) {
          const generatedCode = generateFamilyCode();

          try {
            return await createWithCode({
              ownerUid,
              familyId,
              code: generatedCode,
            });
          } catch (error) {
            if (error.message !== "FAMILY_CODE_TAKEN") {
              throw error;
            }
          }
        }

        throw new HttpsError(
          "resource-exhausted",
          "Impossible de générer un code famille unique."
        );
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  const changeFamilyCode = functions.https.onCall(
    async (data, context) => {
      try {
        const ownerUid = requireAuthenticatedUid(
          context,
          HttpsError
        );
        const familyId = cleanManagedDocumentId(
          data && data.familyId
        );
        const newCode = normalizeManagedFamilyCode(
          data && data.newCode
        );

        const familyRef = db.collection("families").doc(familyId);
        const ownerRef = familyRef
          .collection("members")
          .doc(ownerUid);

        return await db.runTransaction(async (transaction) => {
          const familySnapshot = await transaction.get(familyRef);
          const ownerSnapshot = await transaction.get(ownerRef);

          if (!familySnapshot.exists) {
            throw new Error("FAMILY_NOT_FOUND");
          }

          const family = familySnapshot.data();
          const ownerAuthorization = isAuthenticatedFamilyOwner({
            context,
            familySnapshot,
            memberSnapshot: ownerSnapshot,
            HttpsError,
            allowRepair: true,
          });

          const oldCode = normalizeManagedFamilyCode(family.code);

          if (oldCode === newCode) {
            if (ownerAuthorization.repair) {
              const repairTimestamp = fieldValue.serverTimestamp();
              applyFamilyOwnerRepair({
                transaction,
                memberRef: ownerRef,
                authorization: ownerAuthorization,
                timestamp: repairTimestamp,
              });
              console.warn("Family owner membership repaired", {
                reason: ownerAuthorization.diagnosticCode,
                familyFormat: ownerAuthorization.familyFormat,
              });
            }

            return {
              familyId,
              code: newCode,
              unchanged: true,
            };
          }

          const newCodeRef = db
            .collection("family_codes")
            .doc(newCode);

          const oldCodeRef = db
            .collection("family_codes")
            .doc(oldCode);

          const newCodeSnapshot = await transaction.get(newCodeRef);

          if (
            newCodeSnapshot.exists &&
            newCodeSnapshot.data().familyId !== familyId
          ) {
            throw new Error("FAMILY_CODE_TAKEN");
          }

          const existingCodeQuery = db
            .collection("families")
            .where("code", "==", newCode)
            .limit(1);

          const existingCodeSnapshot = await transaction.get(
            existingCodeQuery
          );

          if (
            !existingCodeSnapshot.empty &&
            existingCodeSnapshot.docs[0].id !== familyId
          ) {
            throw new Error("FAMILY_CODE_TAKEN");
          }

          const oldCodeSnapshot = await transaction.get(oldCodeRef);
          const timestamp = fieldValue.serverTimestamp();

          if (ownerAuthorization.repair) {
            applyFamilyOwnerRepair({
              transaction,
              memberRef: ownerRef,
              authorization: ownerAuthorization,
              timestamp,
            });
            console.warn("Family owner membership repaired", {
              reason: ownerAuthorization.diagnosticCode,
              familyFormat: ownerAuthorization.familyFormat,
            });
          }

          transaction.set(
            newCodeRef,
            buildFamilyCodeIndexData({
              familyId,
              code: newCode,
              ownerUid,
              timestamp,
            })
          );

          transaction.update(familyRef, {
            code: newCode,
          });

          if (
            oldCodeSnapshot.exists &&
            oldCodeSnapshot.data().familyId === familyId
          ) {
            transaction.delete(oldCodeRef);
          }

          return {
            familyId,
            code: newCode,
            unchanged: false,
          };
        });
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  return {
    createFamily,
    changeFamilyCode,
  };
}

module.exports = {
  normalizeManagedFamilyCode,
  cleanManagedDocumentId,
  buildManagedFamilyData,
  buildManagedOwnerData,
  buildFamilyCodeIndexData,
  createFamilyManagementFunctions,
};
