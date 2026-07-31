"use strict";

const OWNER_AUTH_CODES = Object.freeze({
  UNAUTHENTICATED: "OWNER_AUTH_UNAUTHENTICATED",
  FAMILY_NOT_FOUND: "OWNER_AUTH_FAMILY_NOT_FOUND",
  OWNER_UID_MISMATCH: "OWNER_AUTH_UID_MISMATCH",
  MEMBER_MISSING: "OWNER_AUTH_MEMBER_MISSING",
  MEMBER_UID_MISMATCH: "OWNER_AUTH_MEMBER_UID_MISMATCH",
  ROLE_INCORRECT: "OWNER_AUTH_ROLE_INCORRECT",
  MEMBER_INACTIVE: "OWNER_AUTH_MEMBER_INACTIVE",
  HISTORICAL_FORMAT: "OWNER_AUTH_HISTORICAL_FORMAT",
  MEMBER_REPAIRED_MISSING: "OWNER_AUTH_MEMBER_REPAIRED_MISSING",
  MEMBER_REPAIRED_INCOMPLETE: "OWNER_AUTH_MEMBER_REPAIRED_INCOMPLETE",
  AUTHORIZED: "OWNER_AUTH_AUTHORIZED",
});

const FAMILY_FORMATS = Object.freeze({
  MODERN: "modern-v2",
  HISTORICAL_CANONICAL_OWNER: "historical-canonical-ownerUid",
  HISTORICAL_OWNER_ID_ONLY: "historical-ownerId-only",
  HISTORICAL_NO_OWNER: "historical-no-canonical-owner",
});

function hasOwn(object, key) {
  return Object.prototype.hasOwnProperty.call(object, key);
}

function validUid(value) {
  return typeof value === "string" &&
    value.length > 0 &&
    value.length <= 128 &&
    !value.includes("/") &&
    !/[\u0000-\u001f]/.test(value);
}

function familyFormat(family) {
  if (family && validUid(family.ownerUid)) {
    return family.schemaVersion === 2
      ? FAMILY_FORMATS.MODERN
      : FAMILY_FORMATS.HISTORICAL_CANONICAL_OWNER;
  }
  if (family && validUid(family.ownerId)) {
    return FAMILY_FORMATS.HISTORICAL_OWNER_ID_ONLY;
  }
  return FAMILY_FORMATS.HISTORICAL_NO_OWNER;
}

function ownerHttpsError({
  HttpsError,
  code,
  message,
  reason,
  format,
}) {
  return new HttpsError(code, message, {
    reason,
    familyFormat: format,
  });
}

function requireAuthenticatedUid(context, HttpsError) {
  if (!context || !context.auth || !validUid(context.auth.uid)) {
    throw ownerHttpsError({
      HttpsError,
      code: "unauthenticated",
      message: "Une authentification Firebase est requise.",
      reason: OWNER_AUTH_CODES.UNAUTHENTICATED,
      format: null,
    });
  }

  return context.auth.uid;
}

function isAuthenticatedFamilyOwner({
  context,
  familySnapshot,
  memberSnapshot,
  HttpsError,
  allowRepair = true,
}) {
  const authenticatedUid = requireAuthenticatedUid(context, HttpsError);

  if (!familySnapshot || !familySnapshot.exists) {
    throw ownerHttpsError({
      HttpsError,
      code: "not-found",
      message: "Famille introuvable.",
      reason: OWNER_AUTH_CODES.FAMILY_NOT_FOUND,
      format: null,
    });
  }

  const family = familySnapshot.data();
  const format = familyFormat(family);

  // ownerId n'est pas une preuve canonique dans les formats historiques de
  // SKS Family. Seul ownerUid peut être comparé à l'UID Firebase authentifié.
  if (!family || !validUid(family.ownerUid)) {
    throw ownerHttpsError({
      HttpsError,
      code: "failed-precondition",
      message:
        "Cette famille utilise un ancien format sans propriétaire Firebase " +
        "vérifiable. Une migration administrateur séparée est requise.",
      reason: OWNER_AUTH_CODES.HISTORICAL_FORMAT,
      format,
    });
  }

  if (family.ownerUid !== authenticatedUid) {
    throw ownerHttpsError({
      HttpsError,
      code: "permission-denied",
      message:
        "L'identité Firebase de cet appareil ne correspond pas au " +
        "propriétaire enregistré.",
      reason: OWNER_AUTH_CODES.OWNER_UID_MISMATCH,
      format,
    });
  }

  if (!memberSnapshot || !memberSnapshot.exists) {
    if (!allowRepair) {
      throw ownerHttpsError({
        HttpsError,
        code: "failed-precondition",
        message: "Le document membre du propriétaire est absent.",
        reason: OWNER_AUTH_CODES.MEMBER_MISSING,
        format,
      });
    }

    return {
      authorized: true,
      uid: authenticatedUid,
      familyFormat: format,
      diagnosticCode: OWNER_AUTH_CODES.MEMBER_REPAIRED_MISSING,
      repair: {
        missing: true,
        patch: {
          uid: authenticatedUid,
          role: "owner",
          childId: null,
          active: true,
          approvedBy: authenticatedUid,
        },
      },
    };
  }

  const member = memberSnapshot.data() || {};

  if (hasOwn(member, "uid") && member.uid !== authenticatedUid) {
    throw ownerHttpsError({
      HttpsError,
      code: "permission-denied",
      message: "Le document membre contient une identité incohérente.",
      reason: OWNER_AUTH_CODES.MEMBER_UID_MISMATCH,
      format,
    });
  }

  if (hasOwn(member, "active") && member.active !== true) {
    throw ownerHttpsError({
      HttpsError,
      code: "permission-denied",
      message: "Le membre propriétaire n'est pas actif.",
      reason: OWNER_AUTH_CODES.MEMBER_INACTIVE,
      format,
    });
  }

  if (hasOwn(member, "role") && member.role !== "owner") {
    throw ownerHttpsError({
      HttpsError,
      code: "permission-denied",
      message: "Le rôle du membre ne correspond pas au propriétaire.",
      reason: OWNER_AUTH_CODES.ROLE_INCORRECT,
      format,
    });
  }

  const incomplete =
    !hasOwn(member, "uid") ||
    !hasOwn(member, "active") ||
    !hasOwn(member, "role") ||
    member.childId !== null;

  if (incomplete && allowRepair) {
    return {
      authorized: true,
      uid: authenticatedUid,
      familyFormat: format,
      diagnosticCode: OWNER_AUTH_CODES.MEMBER_REPAIRED_INCOMPLETE,
      repair: {
        missing: false,
        patch: {
          uid: authenticatedUid,
          role: "owner",
          childId: null,
          active: true,
        },
      },
    };
  }

  return {
    authorized: true,
    uid: authenticatedUid,
    familyFormat: format,
    diagnosticCode: OWNER_AUTH_CODES.AUTHORIZED,
    repair: null,
  };
}

function applyFamilyOwnerRepair({
  transaction,
  memberRef,
  authorization,
  timestamp,
}) {
  if (!authorization || !authorization.repair) return false;

  const patch = {
    ...authorization.repair.patch,
    ownerAuthorizationRepair: authorization.diagnosticCode,
    ownerAuthorizationRepairedAt: timestamp,
  };

  if (authorization.repair.missing) {
    patch.createdAt = timestamp;
    patch.approvedAt = timestamp;
  }

  transaction.set(memberRef, patch, {merge: true});
  return true;
}

module.exports = {
  OWNER_AUTH_CODES,
  FAMILY_FORMATS,
  familyFormat,
  requireAuthenticatedUid,
  isAuthenticatedFamilyOwner,
  applyFamilyOwnerRepair,
};
