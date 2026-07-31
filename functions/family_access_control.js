"use strict";

const {
  requireAuthenticatedUid,
  isAuthenticatedFamilyOwner,
} = require("./family_owner_authorization");

const FAMILY_ROLES = Object.freeze({
  OWNER: "owner",
  MANAGER: "manager",
  PARENT: "parent",
  CHILD: "child",
});

const FAMILY_PERMISSIONS = Object.freeze({
  MANAGE_JOIN_REQUESTS: "manage-join-requests",
  MANAGE_FAMILY_CODE: "manage-family-code",
  MANAGE_MANAGERS: "manage-managers",
  TRANSFER_OWNERSHIP: "transfer-ownership",
  READ_INBOX: "read-inbox",
});

const FAMILY_ACCESS_CODES = Object.freeze({
  FAMILY_NOT_FOUND: "FAMILY_ACCESS_FAMILY_NOT_FOUND",
  MEMBER_MISSING: "FAMILY_ACCESS_MEMBER_MISSING",
  MEMBER_UID_MISMATCH: "FAMILY_ACCESS_MEMBER_UID_MISMATCH",
  MEMBER_INACTIVE: "FAMILY_ACCESS_MEMBER_INACTIVE",
  ROLE_FORBIDDEN: "FAMILY_ACCESS_ROLE_FORBIDDEN",
  MANAGER_IDENTITY_NOT_DURABLE:
    "FAMILY_ACCESS_MANAGER_IDENTITY_NOT_DURABLE",
});

function deny(HttpsError, code, message, status = "permission-denied") {
  throw new HttpsError(status, message, {reason: code});
}

function normalizeServerRole(value) {
  return value === "familyAdmin" ? FAMILY_ROLES.MANAGER : value;
}

function authProvider(context) {
  const token = context && context.auth && context.auth.token;
  return token && token.firebase && token.firebase.sign_in_provider
    ? token.firebase.sign_in_provider
    : null;
}

function isDurableVerifiedAuth(context) {
  const token = context && context.auth && context.auth.token;
  const provider = authProvider(context);
  return Boolean(
    token &&
    token.email_verified === true &&
    provider &&
    provider !== "anonymous"
  );
}

function isActiveCoherentMember(member, authenticatedUid) {
  return Boolean(
    member &&
    member.uid === authenticatedUid &&
    member.active === true &&
    [
      FAMILY_ROLES.OWNER,
      FAMILY_ROLES.MANAGER,
      FAMILY_ROLES.PARENT,
      FAMILY_ROLES.CHILD,
      "familyAdmin",
    ].includes(member.role)
  );
}

function isManagerPermission(permission) {
  return [
    FAMILY_PERMISSIONS.MANAGE_JOIN_REQUESTS,
    FAMILY_PERMISSIONS.MANAGE_FAMILY_CODE,
    FAMILY_PERMISSIONS.READ_INBOX,
  ].includes(permission);
}

function authorizeFamilyPermission({
  context,
  familySnapshot,
  memberSnapshot,
  HttpsError,
  permission,
  allowOwnerRepair = false,
}) {
  const authenticatedUid = requireAuthenticatedUid(context, HttpsError);
  if (!familySnapshot || !familySnapshot.exists) {
    deny(
      HttpsError,
      FAMILY_ACCESS_CODES.FAMILY_NOT_FOUND,
      "Famille introuvable.",
      "not-found"
    );
  }

  const family = familySnapshot.data();
  const member = memberSnapshot && memberSnapshot.exists
    ? memberSnapshot.data()
    : null;
  const role = normalizeServerRole(member && member.role);

  if (family.ownerUid === authenticatedUid) {
    const ownerAuthorization = isAuthenticatedFamilyOwner({
      context,
      familySnapshot,
      memberSnapshot,
      HttpsError,
      allowRepair: allowOwnerRepair,
    });
    return {
      uid: authenticatedUid,
      role: FAMILY_ROLES.OWNER,
      ownerAuthorization,
    };
  }

  // Un ancien ownerId n'est jamais une preuve de propriété. Le vérificateur
  // propriétaire centralisé produit ici le diagnostic historique dédié, sans
  // créer ni promouvoir de membre.
  if (!family.ownerUid && family.ownerId === authenticatedUid) {
    isAuthenticatedFamilyOwner({
      context,
      familySnapshot,
      memberSnapshot,
      HttpsError,
      allowRepair: false,
    });
  }

  if (!member) {
    deny(
      HttpsError,
      FAMILY_ACCESS_CODES.MEMBER_MISSING,
      "Le membre familial est introuvable."
    );
  }
  if (member.uid !== authenticatedUid) {
    deny(
      HttpsError,
      FAMILY_ACCESS_CODES.MEMBER_UID_MISMATCH,
      "L'identite du membre familial est incoherente."
    );
  }
  if (member.active !== true) {
    deny(
      HttpsError,
      FAMILY_ACCESS_CODES.MEMBER_INACTIVE,
      "Le membre familial est inactif."
    );
  }
  if (!isActiveCoherentMember(member, authenticatedUid)) {
    deny(
      HttpsError,
      FAMILY_ACCESS_CODES.ROLE_FORBIDDEN,
      "Le role familial est invalide."
    );
  }

  if (role === FAMILY_ROLES.MANAGER && isManagerPermission(permission)) {
    if (!isDurableVerifiedAuth(context)) {
      deny(
        HttpsError,
        FAMILY_ACCESS_CODES.MANAGER_IDENTITY_NOT_DURABLE,
        "Le compte du gestionnaire doit etre durable et verifie."
      );
    }
    return {
        uid: authenticatedUid,
        role: FAMILY_ROLES.MANAGER,
        ownerAuthorization: null,
      };
  }

  if (
    permission === FAMILY_PERMISSIONS.READ_INBOX &&
    role === FAMILY_ROLES.PARENT
  ) {
    return {
      uid: authenticatedUid,
      role: FAMILY_ROLES.PARENT,
      ownerAuthorization: null,
    };
  }

  deny(
    HttpsError,
    FAMILY_ACCESS_CODES.ROLE_FORBIDDEN,
    "Le role familial ne permet pas cette operation."
  );
}

module.exports = {
  FAMILY_ROLES,
  FAMILY_PERMISSIONS,
  FAMILY_ACCESS_CODES,
  normalizeServerRole,
  authProvider,
  isDurableVerifiedAuth,
  isActiveCoherentMember,
  authorizeFamilyPermission,
};
