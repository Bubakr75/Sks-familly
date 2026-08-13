"use strict";

const crypto = require("node:crypto");

const {
  cleanId,
} = require("./family_managers");
const {
  authProvider,
  isDurableVerifiedAuth,
} = require("./family_access_control");

const DIAGNOSTIC_CODES = Object.freeze({
  OWNER_COHERENT: "OWNER_COHERENT",
  OWNER_MEMBER_MISSING: "OWNER_MEMBER_MISSING",
  OWNER_MEMBER_INCOHERENT: "OWNER_MEMBER_INCOHERENT",
  HISTORICAL_OWNER_MISMATCH: "HISTORICAL_OWNER_MISMATCH",
  HISTORICAL_OWNER_ID_ONLY: "HISTORICAL_OWNER_ID_ONLY",
  FAMILY_OWNER_MISSING: "FAMILY_OWNER_MISSING",
});

function shortFingerprint(value) {
  return crypto.createHash("sha256")
    .update(`sks-family-diagnostic:${value}`)
    .digest("hex")
    .slice(0, 12);
}

function safeMemberState(member, authenticatedUid) {
  if (!member) return "missing";
  if (member.uid !== authenticatedUid) return "uid-mismatch";
  if (member.active !== true) return "inactive";
  if (!["owner", "manager", "familyAdmin", "parent", "child"]
    .includes(member.role)) {
    return "role-invalid";
  }
  return member.role === "familyAdmin" ? "manager" : member.role;
}

function classifyOwnership({family, currentUid, currentMember, ownerMember}) {
  const currentMemberState = safeMemberState(currentMember, currentUid);
  if (typeof family.ownerUid === "string" && family.ownerUid.length > 0) {
    if (family.ownerUid !== currentUid) {
      return {
        code: DIAGNOSTIC_CODES.HISTORICAL_OWNER_MISMATCH,
        ownershipStatus: "historical-incoherent",
        currentMemberState,
        automaticRepairAllowed: false,
        proofLevel: "insufficient",
      };
    }
    if (!currentMember) {
      return {
        code: DIAGNOSTIC_CODES.OWNER_MEMBER_MISSING,
        ownershipStatus: "canonical-owner-member-missing",
        currentMemberState,
        automaticRepairAllowed: true,
        proofLevel: "strong-canonical-ownerUid",
      };
    }
    if (
      currentMember.uid !== currentUid ||
      currentMember.role !== "owner" ||
      currentMember.active !== true
    ) {
      return {
        code: DIAGNOSTIC_CODES.OWNER_MEMBER_INCOHERENT,
        ownershipStatus: "canonical-owner-member-incoherent",
        currentMemberState,
        automaticRepairAllowed: true,
        proofLevel: "strong-canonical-ownerUid",
      };
    }
    return {
      code: DIAGNOSTIC_CODES.OWNER_COHERENT,
      ownershipStatus: "coherent-owner",
      currentMemberState,
      automaticRepairAllowed: false,
      proofLevel: "strong-canonical-ownerUid",
    };
  }
  if (typeof family.ownerId === "string" && family.ownerId.length > 0) {
    return {
      code: DIAGNOSTIC_CODES.HISTORICAL_OWNER_ID_ONLY,
      ownershipStatus: "historical-ownerId-only",
      currentMemberState,
      automaticRepairAllowed: false,
      proofLevel: "insufficient",
    };
  }
  return {
    code: DIAGNOSTIC_CODES.FAMILY_OWNER_MISSING,
    ownershipStatus: "owner-missing",
    currentMemberState,
    automaticRepairAllowed: false,
    proofLevel: "insufficient",
  };
}

function diagnosticStateFingerprint({
  familyId,
  family,
  currentUid,
  currentMember,
  ownerMember,
}) {
  const stable = {
    familyId,
    ownerUid: family.ownerUid || null,
    ownerId: family.ownerId || null,
    schemaVersion: family.schemaVersion || null,
    migrationStatus: family.migrationStatus || null,
    currentUid,
    currentMember: currentMember
      ? {
          uid: currentMember.uid || null,
          role: currentMember.role || null,
          active: currentMember.active === true,
        }
      : null,
    ownerMember: ownerMember
      ? {
          uid: ownerMember.uid || null,
          role: ownerMember.role || null,
          active: ownerMember.active === true,
        }
      : null,
  };
  return crypto.createHash("sha256")
    .update(JSON.stringify(stable))
    .digest("hex");
}

function createFamilyOwnershipDiagnosticFunctions({
  functions,
  db,
}) {
  const HttpsError = functions.https.HttpsError;

  function requireAuth(context) {
    if (!context || !context.auth || !context.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Authentification Firebase requise.",
        {reason: "DIAGNOSTIC_UNAUTHENTICATED"}
      );
    }
    return context.auth.uid;
  }

  function callableError(error) {
    if (error instanceof HttpsError) return error;
    if (error && error.message === "INVALID_ID") {
      return new HttpsError("invalid-argument", "Famille invalide.");
    }
    console.error("Family ownership diagnostic failed", {
      code: error && error.code ? error.code : "UNKNOWN",
    });
    return new HttpsError("internal", "Diagnostic indisponible.");
  }

  async function buildDiagnostic(data, context) {
    const currentUid = requireAuth(context);
    const familyId = cleanId(data && data.familyId);
    const familyRef = db.collection("families").doc(familyId);
    const familySnapshot = await familyRef.get();
    if (!familySnapshot.exists) {
      throw new HttpsError(
        "not-found",
        "Famille introuvable.",
        {reason: "DIAGNOSTIC_FAMILY_NOT_FOUND"}
      );
    }
    const family = familySnapshot.data();
    const currentMemberSnapshot = await familyRef
      .collection("members")
      .doc(currentUid)
      .get();
    const currentMember = currentMemberSnapshot.exists
      ? currentMemberSnapshot.data()
      : null;
    const canonicalOwnerUid =
      typeof family.ownerUid === "string" &&
      family.ownerUid.length > 0
        ? family.ownerUid
        : null;
    const ownerMemberSnapshot = canonicalOwnerUid
      ? await familyRef.collection("members").doc(canonicalOwnerUid).get()
      : null;
    const ownerMember = ownerMemberSnapshot && ownerMemberSnapshot.exists
      ? ownerMemberSnapshot.data()
      : null;
    const membersSnapshot = await familyRef
      .collection("members")
      .limit(200)
      .get();
    const classification = classifyOwnership({
      family,
      currentUid,
      currentMember,
      ownerMember,
    });
    const roleCounts = {
      owner: 0,
      manager: 0,
      parent: 0,
      child: 0,
      inactive: 0,
      incoherent: 0,
    };
    for (const document of membersSnapshot.docs) {
      const member = document.data();
      if (member.uid !== document.id) {
        roleCounts.incoherent += 1;
      } else if (member.active !== true) {
        roleCounts.inactive += 1;
      } else {
        const role = member.role === "familyAdmin"
          ? "manager"
          : member.role;
        if (Object.hasOwn(roleCounts, role)) {
          roleCounts[role] += 1;
        } else {
          roleCounts.incoherent += 1;
        }
      }
    }
    return {
      projectSelection: shortFingerprint(familyId),
      authentication: {
        provider: authProvider(context) || "unknown",
        emailVerified:
          context.auth.token &&
          context.auth.token.email_verified === true,
        durable: isDurableVerifiedAuth(context),
      },
      ownership: classification,
      structure: {
        schema: family.schemaVersion === 2 ? "modern" : "historical",
        canonicalOwnerMember:
          safeMemberState(ownerMember, canonicalOwnerUid),
        roleCounts,
        truncated: membersSnapshot.size >= 200,
      },
      dryRun: {
        mode: "read-only",
        migrationRequired:
          classification.code ===
          DIAGNOSTIC_CODES.HISTORICAL_OWNER_MISMATCH,
        stateFingerprint: diagnosticStateFingerprint({
          familyId,
          family,
          currentUid,
          currentMember,
          ownerMember,
        }),
        wouldModify: [
          "families/{selectedFamily}",
          "families/{selectedFamily}/members/{expectedOldOwner}",
          "families/{selectedFamily}/members/{expectedNewOwner}",
          "family_codes/{currentCode}",
          "families/{selectedFamily}/_private_audit/{migrationId}",
        ],
      },
    };
  }

  const getFamilyOwnershipDiagnostic = functions.https.onCall(
    async (data, context) => {
      try {
        return await buildDiagnostic(data, context);
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  const prepareHistoricalOwnerMigrationDryRun = functions.https.onCall(
    async (data, context) => {
      try {
        return await buildDiagnostic(data, context);
      } catch (error) {
        throw callableError(error);
      }
    }
  );

  return {
    getFamilyOwnershipDiagnostic,
    prepareHistoricalOwnerMigrationDryRun,
  };
}

module.exports = {
  DIAGNOSTIC_CODES,
  shortFingerprint,
  safeMemberState,
  classifyOwnership,
  diagnosticStateFingerprint,
  createFamilyOwnershipDiagnosticFunctions,
};
