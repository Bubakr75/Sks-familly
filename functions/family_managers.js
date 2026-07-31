"use strict";

const {
  FAMILY_ROLES,
  FAMILY_PERMISSIONS,
  authorizeFamilyPermission,
  isActiveCoherentMember,
} = require("./family_access_control");
const {
  applyFamilyOwnerRepair,
} = require("./family_owner_authorization");

function cleanId(value) {
  if (
    typeof value !== "string" ||
    value.length < 1 ||
    value.length > 128 ||
    value.includes("/") ||
    /[\u0000-\u001f]/.test(value)
  ) {
    throw new Error("INVALID_ID");
  }
  return value;
}

function authUserIsDurableVerified(user) {
  return Boolean(
    user &&
    user.emailVerified === true &&
    Array.isArray(user.providerData) &&
    user.providerData.some(
      (provider) => provider && provider.providerId !== "anonymous"
    )
  );
}

function buildManagerPatch({ownerUid, timestamp}) {
  return {
    role: FAMILY_ROLES.MANAGER,
    childId: null,
    active: true,
    durableAccount: true,
    managerGrantedBy: ownerUid,
    managerGrantedAt: timestamp,
    managerRevokedAt: null,
  };
}

function buildParentPatch({timestamp}) {
  return {
    role: FAMILY_ROLES.PARENT,
    childId: null,
    managerRevokedAt: timestamp,
  };
}

function createFamilyManagerFunctions({
  functions,
  admin,
  db,
  auth = admin.auth(),
}) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  function callableError(error) {
    if (error instanceof HttpsError) return error;
    if (error && error.message === "INVALID_ID") {
      return new HttpsError("invalid-argument", "Identifiant invalide.");
    }
    console.error("Family manager callable failed", {
      code: error && error.code ? error.code : "UNKNOWN",
    });
    return new HttpsError("internal", "Operation impossible.");
  }

  async function ownerTransactionAuthorization({
    transaction,
    familyRef,
    context,
  }) {
    const uid = context.auth && context.auth.uid;
    const familySnapshot = await transaction.get(familyRef);
    const memberRef = familyRef.collection("members").doc(uid || "_");
    const memberSnapshot = await transaction.get(memberRef);
    const authorization = authorizeFamilyPermission({
      context,
      familySnapshot,
      memberSnapshot,
      HttpsError,
      permission: FAMILY_PERMISSIONS.MANAGE_MANAGERS,
      allowOwnerRepair: true,
    });
    return {
      authorization,
      familySnapshot,
      memberRef,
    };
  }

  const listFamilyManagers = functions.https.onCall(async (data, context) => {
    try {
      const familyId = cleanId(data && data.familyId);
      const familyRef = db.collection("families").doc(familyId);
      const uid = context.auth && context.auth.uid;
      const [familySnapshot, ownerMemberSnapshot] = await Promise.all([
        familyRef.get(),
        familyRef.collection("members").doc(uid || "_").get(),
      ]);
      authorizeFamilyPermission({
        context,
        familySnapshot,
        memberSnapshot: ownerMemberSnapshot,
        HttpsError,
        permission: FAMILY_PERMISSIONS.MANAGE_MANAGERS,
      });

      const members = await familyRef.collection("members").limit(200).get();
      const result = [];
      for (const document of members.docs) {
        const member = document.data();
        const role = member.role === "familyAdmin" ? "manager" : member.role;
        if (
          member.active !== true ||
          member.uid !== document.id ||
          !["parent", "manager"].includes(role)
        ) {
          continue;
        }
        let durable = false;
        try {
          durable = authUserIsDurableVerified(
            await auth.getUser(document.id)
          );
        } catch (_) {
          durable = false;
        }
        result.push({
          memberId: document.id,
          displayName:
            typeof member.displayName === "string" &&
            member.displayName.trim().length > 0
              ? member.displayName.trim().slice(0, 80)
              : "Parent",
          role,
          durable,
        });
      }
      return {familyId, members: result};
    } catch (error) {
      throw callableError(error);
    }
  });

  const setFamilyManager = functions.https.onCall(async (data, context) => {
    try {
      const familyId = cleanId(data && data.familyId);
      const targetUid = cleanId(data && data.memberId);
      const targetAuth = await auth.getUser(targetUid);
      if (!authUserIsDurableVerified(targetAuth)) {
        throw new HttpsError(
          "failed-precondition",
          "Le parent doit utiliser un compte durable avec email verifie."
        );
      }

      const familyRef = db.collection("families").doc(familyId);
      const auditRef = familyRef.collection("_private_audit").doc();
      return await db.runTransaction(async (transaction) => {
        const {
          authorization,
          memberRef: ownerMemberRef,
        } = await ownerTransactionAuthorization({
          transaction,
          familyRef,
          context,
        });
        if (authorization.uid === targetUid) {
          throw new HttpsError(
            "failed-precondition",
            "Le proprietaire ne peut pas devenir gestionnaire."
          );
        }

        const targetRef = familyRef.collection("members").doc(targetUid);
        const targetSnapshot = await transaction.get(targetRef);
        const target = targetSnapshot.exists ? targetSnapshot.data() : null;
        const role = target && target.role === "familyAdmin"
          ? "manager"
          : target && target.role;
        if (
          !isActiveCoherentMember(target, targetUid) ||
          !["parent", "manager"].includes(role)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Le gestionnaire doit etre un parent actif."
          );
        }
        const timestamp = fieldValue.serverTimestamp();
        if (authorization.ownerAuthorization &&
            authorization.ownerAuthorization.repair) {
          applyFamilyOwnerRepair({
            transaction,
            memberRef: ownerMemberRef,
            authorization: authorization.ownerAuthorization,
            timestamp,
          });
        }
        transaction.set(
          targetRef,
          buildManagerPatch({
            ownerUid: authorization.uid,
            timestamp,
          }),
          {merge: true}
        );
        transaction.set(
          auditRef,
          {
            type: "manager-granted",
            actorUid: authorization.uid,
            targetUid,
            createdAt: timestamp,
          },
          {merge: true}
        );
        return {familyId, memberId: targetUid, role: "manager"};
      });
    } catch (error) {
      throw callableError(error);
    }
  });

  const revokeFamilyManager = functions.https.onCall(async (data, context) => {
    try {
      const familyId = cleanId(data && data.familyId);
      const targetUid = cleanId(data && data.memberId);
      const familyRef = db.collection("families").doc(familyId);
      const auditRef = familyRef.collection("_private_audit").doc();
      return await db.runTransaction(async (transaction) => {
        const {authorization} = await ownerTransactionAuthorization({
          transaction,
          familyRef,
          context,
        });
        const targetRef = familyRef.collection("members").doc(targetUid);
        const targetSnapshot = await transaction.get(targetRef);
        const target = targetSnapshot.exists ? targetSnapshot.data() : null;
        if (
          !isActiveCoherentMember(target, targetUid) ||
          !["manager", "familyAdmin"].includes(target.role)
        ) {
          throw new HttpsError(
            "failed-precondition",
            "Ce membre n'est pas un gestionnaire actif."
          );
        }
        const timestamp = fieldValue.serverTimestamp();
        transaction.set(
          targetRef,
          buildParentPatch({timestamp}),
          {merge: true}
        );
        transaction.set(
          auditRef,
          {
            type: "manager-revoked",
            actorUid: authorization.uid,
            targetUid,
            createdAt: timestamp,
          },
          {merge: true}
        );
        return {familyId, memberId: targetUid, role: "parent"};
      });
    } catch (error) {
      throw callableError(error);
    }
  });

  const getFamilyAccessContext = functions.https.onCall(
    async (data, context) => {
      try {
        const familyId = cleanId(data && data.familyId);
        const uid = context.auth && context.auth.uid;
        const familyRef = db.collection("families").doc(familyId);
        const [familySnapshot, memberSnapshot] = await Promise.all([
          familyRef.get(),
          familyRef.collection("members").doc(uid || "_").get(),
        ]);
        if (!familySnapshot.exists ||
            !isActiveCoherentMember(
              memberSnapshot.exists ? memberSnapshot.data() : null,
              uid
            )) {
          throw new HttpsError(
            "permission-denied",
            "Membre familial actif requis."
          );
        }
        const family = familySnapshot.data();
        const member = memberSnapshot.data();
        const role = member.role === "familyAdmin"
          ? "manager"
          : member.role;
        const owner = role === "owner" && family.ownerUid === uid;
        const manager = role === "manager" &&
          isDurableVerifiedContext(context);
        return {
          familyId,
          role,
          canManageCode: owner || manager,
          code: owner || manager ? family.code : null,
        };
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  function isDurableVerifiedContext(context) {
    const token = context && context.auth && context.auth.token;
    const provider = token && token.firebase &&
      token.firebase.sign_in_provider;
    return Boolean(
      token &&
      token.email_verified === true &&
      provider &&
      provider !== "anonymous"
    );
  }

  return {
    listFamilyManagers,
    setFamilyManager,
    revokeFamilyManager,
    getFamilyAccessContext,
  };
}

module.exports = {
  cleanId,
  authUserIsDurableVerified,
  buildManagerPatch,
  buildParentPatch,
  createFamilyManagerFunctions,
};
