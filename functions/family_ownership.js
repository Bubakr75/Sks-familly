"use strict";

const crypto = require("node:crypto");

const {
  FAMILY_ROLES,
  FAMILY_PERMISSIONS,
  authorizeFamilyPermission,
  isActiveCoherentMember,
  isDurableVerifiedAuth,
} = require("./family_access_control");
const {
  applyFamilyOwnerRepair,
} = require("./family_owner_authorization");
const {
  cleanId,
  authUserIsDurableVerified,
} = require("./family_managers");

const RECENT_AUTH_SECONDS = 5 * 60;
const RECOVERY_VALIDITY_SECONDS = 90 * 24 * 60 * 60;
const TRANSFER_CONFIRMATION = "TRANSFERER LA PROPRIETE";

function normalizedVerifiedEmail(context) {
  const token = context && context.auth && context.auth.token;
  if (
    !token ||
    token.email_verified !== true ||
    typeof token.email !== "string"
  ) {
    return null;
  }
  const email = token.email.trim().toLowerCase();
  return email.includes("@") && email.length <= 254 ? email : null;
}

function requireDurableRecentAuth(context, HttpsError, nowSeconds) {
  if (!context || !context.auth || !context.auth.uid) {
    throw new HttpsError("unauthenticated", "Authentification requise.");
  }
  if (!isDurableVerifiedAuth(context) || !normalizedVerifiedEmail(context)) {
    throw new HttpsError(
      "failed-precondition",
      "Un compte durable avec email verifie est requis."
    );
  }
  const authTime = context.auth.token && context.auth.token.auth_time;
  if (
    typeof authTime !== "number" ||
    authTime > nowSeconds + 30 ||
    nowSeconds - authTime > RECENT_AUTH_SECONDS
  ) {
    throw new HttpsError(
      "failed-precondition",
      "Une authentification recente est requise.",
      {reason: "AUTH_RECENT_REQUIRED"}
    );
  }
  return context.auth.uid;
}

function emailHash(email) {
  return crypto.createHash("sha256").update(email).digest("hex");
}

function newRecoverySecret() {
  return crypto.randomBytes(32).toString("base64url");
}

function hashRecoverySecret(secret, salt = crypto.randomBytes(16)) {
  if (
    typeof secret !== "string" ||
    secret.length < 40 ||
    secret.length > 128
  ) {
    throw new Error("INVALID_RECOVERY_SECRET");
  }
  const normalizedSalt = Buffer.isBuffer(salt)
    ? salt
    : Buffer.from(salt, "base64");
  if (normalizedSalt.length !== 16) {
    throw new Error("INVALID_RECOVERY_SALT");
  }
  const derived = crypto.scryptSync(
    secret,
    normalizedSalt,
    32,
    {N: 32768, r: 8, p: 1, maxmem: 64 * 1024 * 1024}
  );
  return {
    algorithm: "scrypt-v1",
    salt: normalizedSalt.toString("base64"),
    hash: derived.toString("base64"),
  };
}

function recoverySecretMatches(secret, record) {
  if (
    !record ||
    record.algorithm !== "scrypt-v1" ||
    typeof record.salt !== "string" ||
    typeof record.hash !== "string"
  ) {
    return false;
  }
  try {
    const candidate = hashRecoverySecret(secret, record.salt);
    const expected = Buffer.from(record.hash, "base64");
    const actual = Buffer.from(candidate.hash, "base64");
    return expected.length === actual.length &&
      crypto.timingSafeEqual(expected, actual);
  } catch (_) {
    return false;
  }
}

function targetRoleAfterTransfer(value) {
  if (value === FAMILY_ROLES.PARENT) return FAMILY_ROLES.PARENT;
  if (value === FAMILY_ROLES.MANAGER) return FAMILY_ROLES.MANAGER;
  throw new Error("INVALID_PREVIOUS_OWNER_ROLE");
}

function createFamilyOwnershipFunctions({
  functions,
  admin,
  db,
  auth = admin.auth(),
  nowSeconds = () => Math.floor(Date.now() / 1000),
}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;
  const timestampFromMillis = admin.firestore.Timestamp.fromMillis;

  function callableError(error) {
    if (error instanceof HttpsError) return error;
    if (
      error &&
      [
        "INVALID_ID",
        "INVALID_PREVIOUS_OWNER_ROLE",
        "INVALID_RECOVERY_SECRET",
        "INVALID_RECOVERY_SALT",
      ].includes(error.message)
    ) {
      return new HttpsError("invalid-argument", "Parametre invalide.");
    }
    console.error("Family ownership callable failed", {
      code: error && error.code ? error.code : "UNKNOWN",
    });
    return new HttpsError("internal", "Operation impossible.");
  }

  async function readOwnerAuthorization({
    transaction,
    familyRef,
    context,
  }) {
    const uid = context.auth.uid;
    const familySnapshot = await transaction.get(familyRef);
    const memberRef = familyRef.collection("members").doc(uid);
    const memberSnapshot = await transaction.get(memberRef);
    const authorization = authorizeFamilyPermission({
      context,
      familySnapshot,
      memberSnapshot,
      HttpsError,
      permission: FAMILY_PERMISSIONS.TRANSFER_OWNERSHIP,
      allowOwnerRepair: true,
    });
    return {authorization, familySnapshot, memberRef};
  }

  const transferFamilyOwnership = functions.https.onCall(
    async (data, context) => {
      try {
        const actorUid = requireDurableRecentAuth(
          context,
          HttpsError,
          nowSeconds()
        );
        const familyId = cleanId(data && data.familyId);
        const targetUid = cleanId(data && data.targetMemberId);
        const operationId = cleanId(data && data.operationId);
        const previousOwnerRole = targetRoleAfterTransfer(
          data && data.previousOwnerRole
        );
        if (data && data.confirmation !== TRANSFER_CONFIRMATION) {
          throw new HttpsError(
            "failed-precondition",
            "La double confirmation est requise."
          );
        }
        if (targetUid === actorUid) {
          throw new HttpsError(
            "failed-precondition",
            "Le destinataire doit etre un autre parent."
          );
        }
        const targetUser = await auth.getUser(targetUid);
        if (!authUserIsDurableVerified(targetUser)) {
          throw new HttpsError(
            "failed-precondition",
            "Le destinataire doit avoir un compte durable verifie."
          );
        }

        const familyRef = db.collection("families").doc(familyId);
        const operationRef = familyRef
          .collection("_private_ownership_operations")
          .doc(operationId);
        const auditRef = familyRef
          .collection("_private_audit")
          .doc(`ownership-${operationId}`);

        return await db.runTransaction(async (transaction) => {
          const operationSnapshot = await transaction.get(operationRef);
          const familySnapshot = await transaction.get(familyRef);
          if (operationSnapshot.exists) {
            const operation = operationSnapshot.data();
            const family = familySnapshot.exists
              ? familySnapshot.data()
              : null;
            if (
              operation.type === "ownership-transfer" &&
              operation.actorUid === actorUid &&
              operation.targetUid === targetUid &&
              family &&
              family.ownerUid === targetUid
            ) {
              return {
                familyId,
                status: "completed",
                idempotent: true,
              };
            }
            throw new HttpsError(
              "already-exists",
              "Cet identifiant d'operation est deja utilise."
            );
          }

          const ownerMemberRef = familyRef
            .collection("members")
            .doc(actorUid);
          const ownerMemberSnapshot = await transaction.get(ownerMemberRef);
          const authorization = authorizeFamilyPermission({
            context,
            familySnapshot,
            memberSnapshot: ownerMemberSnapshot,
            HttpsError,
            permission: FAMILY_PERMISSIONS.TRANSFER_OWNERSHIP,
            allowOwnerRepair: true,
          });
          const targetRef = familyRef.collection("members").doc(targetUid);
          const targetSnapshot = await transaction.get(targetRef);
          const target = targetSnapshot.exists ? targetSnapshot.data() : null;
          const targetRole = target && target.role === "familyAdmin"
            ? FAMILY_ROLES.MANAGER
            : target && target.role;
          if (
            !isActiveCoherentMember(target, targetUid) ||
            ![FAMILY_ROLES.PARENT, FAMILY_ROLES.MANAGER].includes(targetRole)
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Le destinataire doit etre un parent actif."
            );
          }

          const family = familySnapshot.data();
          const codeRef = typeof family.code === "string"
            ? db.collection("family_codes").doc(family.code)
            : null;
          const codeSnapshot = codeRef
            ? await transaction.get(codeRef)
            : null;
          const timestamp = fieldValue.serverTimestamp();
          if (
            authorization.ownerAuthorization &&
            authorization.ownerAuthorization.repair
          ) {
            applyFamilyOwnerRepair({
              transaction,
              memberRef: ownerMemberRef,
              authorization: authorization.ownerAuthorization,
              timestamp,
            });
          }
          transaction.update(familyRef, {
            ownerUid: targetUid,
            ownershipUpdatedAt: timestamp,
          });
          transaction.set(
            ownerMemberRef,
            {
              role: previousOwnerRole,
              childId: null,
              active: true,
              ownershipTransferredAt: timestamp,
            },
            {merge: true}
          );
          transaction.set(
            targetRef,
            {
              uid: targetUid,
              role: FAMILY_ROLES.OWNER,
              childId: null,
              active: true,
              durableAccount: true,
              ownershipReceivedAt: timestamp,
            },
            {merge: true}
          );
          if (
            codeRef &&
            codeSnapshot &&
            codeSnapshot.exists &&
            codeSnapshot.data().familyId === familyId
          ) {
            transaction.set(
              codeRef,
              {ownerUid: targetUid, updatedAt: timestamp},
              {merge: true}
            );
          }
          transaction.create(operationRef, {
            type: "ownership-transfer",
            actorUid,
            targetUid,
            previousOwnerRole,
            createdAt: timestamp,
          });
          transaction.create(auditRef, {
            type: "ownership-transfer",
            previousOwnerUid: actorUid,
            newOwnerUid: targetUid,
            previousOwnerRole,
            createdAt: timestamp,
          });
          return {familyId, status: "completed", idempotent: false};
        });
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  const generateFamilyRecoveryCode = functions.https.onCall(
    async (data, context) => {
      try {
        const ownerUid = requireDurableRecentAuth(
          context,
          HttpsError,
          nowSeconds()
        );
        const familyId = cleanId(data && data.familyId);
        const email = normalizedVerifiedEmail(context);
        const secret = newRecoverySecret();
        const secured = hashRecoverySecret(secret);
        const familyRef = db.collection("families").doc(familyId);
        const recoveryRef = familyRef
          .collection("_private_recovery")
          .doc("current");
        await db.runTransaction(async (transaction) => {
          const {authorization, memberRef} =
            await readOwnerAuthorization({
              transaction,
              familyRef,
              context,
            });
          const timestamp = fieldValue.serverTimestamp();
          if (
            authorization.ownerAuthorization &&
            authorization.ownerAuthorization.repair
          ) {
            applyFamilyOwnerRepair({
              transaction,
              memberRef,
              authorization: authorization.ownerAuthorization,
              timestamp,
            });
          }
          transaction.set(recoveryRef, {
            ...secured,
            ownerUid,
            ownerEmailHash: emailHash(email),
            createdAt: timestamp,
            expiresAt: timestampFromMillis(
              (nowSeconds() + RECOVERY_VALIDITY_SECONDS) * 1000
            ),
            revoked: false,
            used: false,
          });
          transaction.create(
            familyRef.collection("_private_audit").doc(),
            {
              type: "recovery-code-generated",
              actorUid: ownerUid,
              createdAt: timestamp,
            }
          );
        });
        return {
          familyId,
          recoveryCode: secret,
          expiresInDays: 90,
        };
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  const revokeFamilyRecoveryCode = functions.https.onCall(
    async (data, context) => {
      try {
        const ownerUid = requireDurableRecentAuth(
          context,
          HttpsError,
          nowSeconds()
        );
        const familyId = cleanId(data && data.familyId);
        const familyRef = db.collection("families").doc(familyId);
        const recoveryRef = familyRef
          .collection("_private_recovery")
          .doc("current");
        await db.runTransaction(async (transaction) => {
          await readOwnerAuthorization({transaction, familyRef, context});
          const recoverySnapshot = await transaction.get(recoveryRef);
          const timestamp = fieldValue.serverTimestamp();
          if (recoverySnapshot.exists) {
            transaction.set(
              recoveryRef,
              {revoked: true, revokedAt: timestamp},
              {merge: true}
            );
          }
          transaction.create(
            familyRef.collection("_private_audit").doc(),
            {
              type: "recovery-code-revoked",
              actorUid: ownerUid,
              createdAt: timestamp,
            }
          );
        });
        return {familyId, status: "revoked"};
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  const recoverFamilyOwnership = functions.https.onCall(
    async (data, context) => {
      try {
        const newOwnerUid = requireDurableRecentAuth(
          context,
          HttpsError,
          nowSeconds()
        );
        const familyId = cleanId(data && data.familyId);
        const operationId = cleanId(data && data.operationId);
        const secret = data && data.recoveryCode;
        const email = normalizedVerifiedEmail(context);
        if (data && data.confirmation !== "RECUPERER LA PROPRIETE") {
          throw new HttpsError(
            "failed-precondition",
            "La confirmation de recuperation est requise."
          );
        }
        const familyRef = db.collection("families").doc(familyId);
        const recoveryRef = familyRef
          .collection("_private_recovery")
          .doc("current");
        const operationRef = familyRef
          .collection("_private_ownership_operations")
          .doc(operationId);
        return await db.runTransaction(async (transaction) => {
          const operationSnapshot = await transaction.get(operationRef);
          const familySnapshot = await transaction.get(familyRef);
          if (!familySnapshot.exists) {
            throw new HttpsError("not-found", "Famille introuvable.");
          }
          if (operationSnapshot.exists) {
            const operation = operationSnapshot.data();
            if (
              operation.type === "ownership-recovery" &&
              operation.targetUid === newOwnerUid &&
              familySnapshot.data().ownerUid === newOwnerUid
            ) {
              return {familyId, status: "completed", idempotent: true};
            }
            throw new HttpsError(
              "already-exists",
              "Cet identifiant d'operation est deja utilise."
            );
          }
          const recoverySnapshot = await transaction.get(recoveryRef);
          if (!recoverySnapshot.exists) {
            throw new HttpsError(
              "failed-precondition",
              "Aucun code de recuperation actif."
            );
          }
          const recovery = recoverySnapshot.data();
          const expiresAt = recovery.expiresAt &&
            typeof recovery.expiresAt.toMillis === "function"
            ? recovery.expiresAt.toMillis()
            : 0;
          if (
            recovery.revoked === true ||
            recovery.used === true ||
            expiresAt <= nowSeconds() * 1000 ||
            recovery.ownerEmailHash !== emailHash(email) ||
            !recoverySecretMatches(secret, recovery)
          ) {
            throw new HttpsError(
              "permission-denied",
              "Preuve de recuperation invalide, expiree ou deja utilisee."
            );
          }

          const family = familySnapshot.data();
          const oldOwnerUid = cleanId(family.ownerUid);
          const oldOwnerRef = familyRef
            .collection("members")
            .doc(oldOwnerUid);
          const newOwnerRef = familyRef
            .collection("members")
            .doc(newOwnerUid);
          const [oldOwnerSnapshot, newOwnerSnapshot] = await Promise.all([
            transaction.get(oldOwnerRef),
            transaction.get(newOwnerRef),
          ]);
          const existingNewMember = newOwnerSnapshot.exists
            ? newOwnerSnapshot.data()
            : null;
          if (
            existingNewMember &&
            (
              existingNewMember.uid !== newOwnerUid ||
              existingNewMember.role === FAMILY_ROLES.CHILD ||
              existingNewMember.active === false
            )
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Le compte de recuperation est incompatible avec ce membre."
            );
          }
          const codeRef = typeof family.code === "string"
            ? db.collection("family_codes").doc(family.code)
            : null;
          const codeSnapshot = codeRef
            ? await transaction.get(codeRef)
            : null;
          const timestamp = fieldValue.serverTimestamp();
          transaction.update(familyRef, {
            ownerUid: newOwnerUid,
            ownershipUpdatedAt: timestamp,
          });
          if (oldOwnerUid !== newOwnerUid && oldOwnerSnapshot.exists) {
            transaction.set(
              oldOwnerRef,
              {
                role: FAMILY_ROLES.MANAGER,
                childId: null,
                active: true,
                ownershipRecoveredAt: timestamp,
              },
              {merge: true}
            );
          }
          transaction.set(
            newOwnerRef,
            {
              uid: newOwnerUid,
              role: FAMILY_ROLES.OWNER,
              childId: null,
              active: true,
              durableAccount: true,
              ownershipReceivedAt: timestamp,
            },
            {merge: true}
          );
          if (
            codeRef &&
            codeSnapshot &&
            codeSnapshot.exists &&
            codeSnapshot.data().familyId === familyId
          ) {
            transaction.set(
              codeRef,
              {ownerUid: newOwnerUid, updatedAt: timestamp},
              {merge: true}
            );
          }
          transaction.set(
            recoveryRef,
            {
              used: true,
              usedAt: timestamp,
              usedBy: newOwnerUid,
            },
            {merge: true}
          );
          transaction.create(operationRef, {
            type: "ownership-recovery",
            previousOwnerUid: oldOwnerUid,
            targetUid: newOwnerUid,
            createdAt: timestamp,
          });
          transaction.create(
            familyRef
              .collection("_private_audit")
              .doc(`recovery-${operationId}`),
            {
              type: "ownership-recovery",
              previousOwnerUid: oldOwnerUid,
              newOwnerUid,
              createdAt: timestamp,
            }
          );
          return {familyId, status: "completed", idempotent: false};
        });
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  return {
    transferFamilyOwnership,
    generateFamilyRecoveryCode,
    revokeFamilyRecoveryCode,
    recoverFamilyOwnership,
  };
}

module.exports = {
  RECENT_AUTH_SECONDS,
  RECOVERY_VALIDITY_SECONDS,
  TRANSFER_CONFIRMATION,
  normalizedVerifiedEmail,
  requireDurableRecentAuth,
  emailHash,
  newRecoverySecret,
  hashRecoverySecret,
  recoverySecretMatches,
  targetRoleAfterTransfer,
  createFamilyOwnershipFunctions,
};
