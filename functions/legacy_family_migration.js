"use strict";

const crypto = require("crypto");

const CLAIM_STATUS_PENDING = "pending";
const CLAIM_STATUS_USED = "used";
const MIGRATION_SECRET_PATTERN = /^[A-Za-z0-9_-]{32,200}$/;
const CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function cleanMigrationSecret(value) {
  if (typeof value !== "string") {
    throw new Error("INVALID_MIGRATION_SECRET");
  }

  const secret = value.trim();

  if (!MIGRATION_SECRET_PATTERN.test(secret)) {
    throw new Error("INVALID_MIGRATION_SECRET");
  }

  return secret;
}

function hashMigrationSecret(value) {
  const secret = cleanMigrationSecret(value);

  return crypto
    .createHash("sha256")
    .update(secret, "utf8")
    .digest("hex");
}

function hashesMatch(left, right) {
  if (
    typeof left !== "string" ||
    typeof right !== "string" ||
    left.length !== 64 ||
    right.length !== 64
  ) {
    return false;
  }

  return crypto.timingSafeEqual(
    Buffer.from(left, "hex"),
    Buffer.from(right, "hex")
  );
}

function timestampToMillis(value) {
  if (value && typeof value.toMillis === "function") {
    return value.toMillis();
  }

  if (value instanceof Date) {
    return value.getTime();
  }

  if (typeof value === "number" && Number.isFinite(value)) {
    return value;
  }

  return Number.NaN;
}

function validateMigrationClaim({
  claim,
  familyId,
  secret,
  nowMillis,
}) {
  if (!claim || typeof claim !== "object") {
    throw new Error("MIGRATION_CLAIM_NOT_FOUND");
  }

  if (claim.familyId !== familyId) {
    throw new Error("MIGRATION_CLAIM_MISMATCH");
  }

  if (
    claim.status !== CLAIM_STATUS_PENDING ||
    claim.usedAt ||
    claim.usedBy
  ) {
    throw new Error("MIGRATION_CLAIM_USED");
  }

  const expiresAtMillis = timestampToMillis(claim.expiresAt);

  if (
    !Number.isFinite(expiresAtMillis) ||
    expiresAtMillis <= nowMillis
  ) {
    throw new Error("MIGRATION_CLAIM_EXPIRED");
  }

  const suppliedHash = hashMigrationSecret(secret);

  if (!hashesMatch(suppliedHash, claim.secretHash)) {
    throw new Error("INVALID_MIGRATION_SECRET");
  }

  return true;
}

function generateReplacementCode() {
  let code = "";

  for (let index = 0; index < 6; index += 1) {
    code += CODE_CHARS[
      crypto.randomInt(0, CODE_CHARS.length)
    ];
  }

  return code;
}

function buildMigratedFamilyData({
  ownerUid,
  code,
  timestamp,
  memberCount,
}) {
  return {
    ownerUid,
    code,
    schemaVersion: 2,
    migrationStatus: "migrated",
    migratedBy: ownerUid,
    migratedAt: timestamp,
    memberCount:
      Number.isInteger(memberCount) && memberCount > 0
        ? memberCount
        : 1,
  };
}

function buildMigratedOwnerData({
  ownerUid,
  timestamp,
}) {
  return {
    uid: ownerUid,
    role: "owner",
    childId: null,
    active: true,
    createdAt: timestamp,
    approvedBy: ownerUid,
    approvedAt: timestamp,
    migrationSource: "legacy-family",
  };
}

function buildMigrationCodeIndexData({
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

function createLegacyFamilyMigrationFunctions({
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
      case "INVALID_DOCUMENT_ID":
      case "INVALID_MIGRATION_SECRET":
        return new HttpsError(
          "invalid-argument",
          "Autorisation de migration invalide."
        );

      case "FAMILY_NOT_FOUND":
      case "MIGRATION_CLAIM_NOT_FOUND":
        return new HttpsError(
          "not-found",
          "Migration ou famille introuvable."
        );

      case "MIGRATION_CLAIM_EXPIRED":
        return new HttpsError(
          "deadline-exceeded",
          "L'autorisation de migration a expiré."
        );

      case "MIGRATION_CLAIM_USED":
        return new HttpsError(
          "failed-precondition",
          "Cette autorisation de migration a déjà été utilisée."
        );

      case "MIGRATION_CLAIM_MISMATCH":
      case "FAMILY_ALREADY_MANAGED":
      case "LEGACY_MEMBERS_PRESENT":
        return new HttpsError(
          "failed-precondition",
          "Cette famille ne peut pas être migrée automatiquement."
        );

      case "FAMILY_CODE_TAKEN":
        return new HttpsError(
          "already-exists",
          "Le nouveau code famille est déjà utilisé."
        );

      default:
        console.error("Legacy family migration error:", error);

        return new HttpsError(
          "internal",
          "Impossible de migrer la famille pour le moment."
        );
    }
  }

  async function migrateWithCode({
    ownerUid,
    familyId,
    migrationSecret,
    replacementCode,
  }) {
    const familyRef = db.collection("families").doc(familyId);
    const ownerRef = familyRef.collection("members").doc(ownerUid);
    const membersQuery = familyRef
      .collection("members")
      .limit(2);

    const claimRef = db
      .collection("legacy_family_migration_claims")
      .doc(familyId);

    const newCodeRef = db
      .collection("family_codes")
      .doc(replacementCode);

    const duplicateCodeQuery = db
      .collection("families")
      .where("code", "==", replacementCode)
      .limit(1);

    return db.runTransaction(async (transaction) => {
      const familySnapshot = await transaction.get(familyRef);
      const claimSnapshot = await transaction.get(claimRef);
      const ownerSnapshot = await transaction.get(ownerRef);
      const membersSnapshot = await transaction.get(membersQuery);
      const newCodeSnapshot = await transaction.get(newCodeRef);
      const duplicateCodeSnapshot = await transaction.get(
        duplicateCodeQuery
      );

      if (!familySnapshot.exists) {
        throw new Error("FAMILY_NOT_FOUND");
      }

      if (!claimSnapshot.exists) {
        throw new Error("MIGRATION_CLAIM_NOT_FOUND");
      }

      const family = familySnapshot.data();
      const claim = claimSnapshot.data();

      if (
        claim.status === CLAIM_STATUS_USED &&
        claim.usedBy === ownerUid &&
        family.ownerUid === ownerUid &&
        ownerSnapshot.exists &&
        ownerSnapshot.data().role === "owner" &&
        ownerSnapshot.data().active === true
      ) {
        return {
          familyId,
          code: family.code,
          alreadyMigrated: true,
        };
      }

      validateMigrationClaim({
        claim,
        familyId,
        secret: migrationSecret,
        nowMillis: Date.now(),
      });

      if (
        family.ownerUid ||
        family.schemaVersion === 2 ||
        family.migrationStatus === "migrated"
      ) {
        throw new Error("FAMILY_ALREADY_MANAGED");
      }

      if (!membersSnapshot.empty || ownerSnapshot.exists) {
        throw new Error("LEGACY_MEMBERS_PRESENT");
      }

      if (newCodeSnapshot.exists) {
        throw new Error("FAMILY_CODE_TAKEN");
      }

      if (!duplicateCodeSnapshot.empty) {
        throw new Error("FAMILY_CODE_TAKEN");
      }

      const oldCode =
        typeof family.code === "string"
          ? family.code.trim().toUpperCase()
          : "";

      const oldCodeRef = oldCode
        ? db.collection("family_codes").doc(oldCode)
        : null;

      const oldCodeSnapshot = oldCodeRef
        ? await transaction.get(oldCodeRef)
        : null;

      const timestamp = fieldValue.serverTimestamp();

      transaction.set(
        newCodeRef,
        buildMigrationCodeIndexData({
          familyId,
          code: replacementCode,
          ownerUid,
          timestamp,
        })
      );

      transaction.set(
        ownerRef,
        buildMigratedOwnerData({
          ownerUid,
          timestamp,
        })
      );

      transaction.update(
        familyRef,
        buildMigratedFamilyData({
          ownerUid,
          code: replacementCode,
          timestamp,
          memberCount: family.memberCount,
        })
      );

      transaction.update(claimRef, {
        status: CLAIM_STATUS_USED,
        usedBy: ownerUid,
        usedAt: timestamp,
        replacementCode,
      });

      if (
        oldCodeSnapshot &&
        oldCodeSnapshot.exists &&
        oldCodeSnapshot.data().familyId === familyId
      ) {
        transaction.delete(oldCodeRef);
      }

      return {
        familyId,
        code: replacementCode,
        alreadyMigrated: false,
      };
    });
  }

  const migrateLegacyFamily = functions.https.onCall(
    async (data, context) => {
      try {
        const ownerUid = requireAuth(context);

        const familyId =
          typeof (data && data.familyId) === "string"
            ? data.familyId.trim()
            : "";

        if (
          !familyId ||
          familyId.length > 200 ||
          familyId.includes("/")
        ) {
          throw new Error("INVALID_DOCUMENT_ID");
        }

        const migrationSecret = cleanMigrationSecret(
          data && data.migrationSecret
        );

        for (let attempt = 0; attempt < 12; attempt += 1) {
          const replacementCode = generateReplacementCode();

          try {
            return await migrateWithCode({
              ownerUid,
              familyId,
              migrationSecret,
              replacementCode,
            });
          } catch (error) {
            if (error.message !== "FAMILY_CODE_TAKEN") {
              throw error;
            }
          }
        }

        throw new HttpsError(
          "resource-exhausted",
          "Impossible de générer un nouveau code famille."
        );
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  return {
    migrateLegacyFamily,
  };
}

module.exports = {
  cleanMigrationSecret,
  hashMigrationSecret,
  validateMigrationClaim,
  buildMigratedFamilyData,
  buildMigratedOwnerData,
  buildMigrationCodeIndexData,
  createLegacyFamilyMigrationFunctions,
};