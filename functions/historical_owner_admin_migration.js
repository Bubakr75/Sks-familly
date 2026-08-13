"use strict";

const crypto = require("node:crypto");

const REQUIRED_PROJECT = "sks-familly-3f205";

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const item = argv[index];
    if (!item.startsWith("--")) continue;
    const key = item.slice(2);
    if (["dry-run", "apply"].includes(key)) {
      args[key] = true;
    } else {
      args[key] = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

function cleanRequiredId(value, label) {
  if (
    typeof value !== "string" ||
    value.length < 1 ||
    value.length > 128 ||
    value.includes("/") ||
    /[\u0000-\u001f]/.test(value)
  ) {
    throw new Error(`INVALID_${label}`);
  }
  return value;
}

function assertMigrationSafety(args) {
  if (args.project !== REQUIRED_PROJECT) {
    throw new Error("PROJECT_MISMATCH");
  }
  if (Boolean(args["dry-run"]) === Boolean(args.apply)) {
    throw new Error("EXACTLY_ONE_MODE_REQUIRED");
  }
  cleanRequiredId(args["family-id"], "FAMILY_ID");
  cleanRequiredId(args["expected-old-owner-uid"], "OLD_OWNER_UID");
  cleanRequiredId(args["expected-new-owner-uid"], "NEW_OWNER_UID");
  if (
    args["expected-old-owner-uid"] === args["expected-new-owner-uid"]
  ) {
    throw new Error("OWNER_UIDS_MUST_DIFFER");
  }
  if (args.apply) {
    if (args.confirmation !== "APPLIQUER-MIGRATION-PROPRIETAIRE") {
      throw new Error("EXPLICIT_CONFIRMATION_REQUIRED");
    }
    if (
      typeof args["expected-state-hash"] !== "string" ||
      !/^[a-f0-9]{64}$/.test(args["expected-state-hash"])
    ) {
      throw new Error("EXPECTED_STATE_HASH_REQUIRED");
    }
    cleanRequiredId(args["migration-id"], "MIGRATION_ID");
  }
}

function stableMember(member) {
  return member
    ? {
        uid: member.uid || null,
        role: member.role || null,
        active: member.active === true,
        childId: member.childId || null,
      }
    : null;
}

function migrationStateHash({
  familyId,
  family,
  oldMember,
  newMember,
  codeIndex,
}) {
  return crypto.createHash("sha256").update(JSON.stringify({
    familyId,
    family: {
      ownerUid: family.ownerUid || null,
      ownerId: family.ownerId || null,
      code: family.code || null,
      schemaVersion: family.schemaVersion || null,
      migrationStatus: family.migrationStatus || null,
    },
    oldMember: stableMember(oldMember),
    newMember: stableMember(newMember),
    codeIndex: codeIndex
      ? {
          familyId: codeIndex.familyId || null,
          ownerUid: codeIndex.ownerUid || null,
          code: codeIndex.code || null,
        }
      : null,
  })).digest("hex");
}

function validateDryRunState({
  family,
  expectedOldOwnerUid,
  expectedNewOwnerUid,
  oldMember,
  newMember,
  newAuthUser,
}) {
  if (!family) throw new Error("FAMILY_NOT_FOUND");
  if (family.ownerUid !== expectedOldOwnerUid) {
    throw new Error("OLD_OWNER_STATE_MISMATCH");
  }
  if (
    !newAuthUser ||
    newAuthUser.uid !== expectedNewOwnerUid ||
    newAuthUser.emailVerified !== true ||
    !Array.isArray(newAuthUser.providerData) ||
    !newAuthUser.providerData.some(
      (provider) => provider && provider.providerId !== "anonymous"
    )
  ) {
    throw new Error("NEW_OWNER_NOT_DURABLE_VERIFIED");
  }
  if (
    oldMember &&
    (
      oldMember.uid !== expectedOldOwnerUid ||
      oldMember.role !== "owner" ||
      oldMember.active !== true
    )
  ) {
    throw new Error("OLD_OWNER_MEMBER_INCOHERENT");
  }
  if (
    newMember &&
    (
      newMember.uid !== expectedNewOwnerUid ||
      newMember.active === false ||
      !["parent", "manager", "familyAdmin"].includes(newMember.role)
    )
  ) {
    throw new Error("NEW_OWNER_MEMBER_INCOMPATIBLE");
  }
  return true;
}

function anonymizedReport({
  familyId,
  family,
  oldMember,
  newMember,
  codeIndex,
}) {
  return {
    mode: "dry-run",
    selectedFamily: crypto.createHash("sha256")
      .update(`selected:${familyId}`)
      .digest("hex")
      .slice(0, 12),
    ownerMismatchConfirmed: true,
    oldOwnerMember: oldMember ? "coherent-active-owner" : "missing",
    newOwnerMember: newMember ? "compatible-existing" : "will-be-created",
    codeIndex: codeIndex ? "will-update-owner" : "absent-no-write",
    oldOwnerTokens:
      "will-disable-records-bound-to-expected-old-owner-at-apply",
    automaticRepair: false,
    proofLevel: "administrator-confirmation-required",
    stateHash: migrationStateHash({
      familyId,
      family,
      oldMember,
      newMember,
      codeIndex,
    }),
    documents: [
      "families/{selectedFamily}",
      "families/{selectedFamily}/members/{expectedOldOwner}",
      "families/{selectedFamily}/members/{expectedNewOwner}",
      "family_codes/{currentCode}",
      "families/{selectedFamily}/fcm_tokens/{oldOwnerDevices}",
      "families/{selectedFamily}/_private_audit/{migrationId}",
    ],
    deletes: 0,
  };
}

async function readExactState({db, auth, args}) {
  const familyId = args["family-id"];
  const oldUid = args["expected-old-owner-uid"];
  const newUid = args["expected-new-owner-uid"];
  const familyRef = db.collection("families").doc(familyId);
  const familySnapshot = await familyRef.get();
  if (!familySnapshot.exists) throw new Error("FAMILY_NOT_FOUND");
  const family = familySnapshot.data();
  const [oldSnapshot, newSnapshot, newAuthUser] = await Promise.all([
    familyRef.collection("members").doc(oldUid).get(),
    familyRef.collection("members").doc(newUid).get(),
    auth.getUser(newUid),
  ]);
  const codeRef =
    typeof family.code === "string" && family.code.length > 0
      ? db.collection("family_codes").doc(family.code)
      : null;
  const codeSnapshot = codeRef ? await codeRef.get() : null;
  const state = {
    familyId,
    family,
    oldMember: oldSnapshot.exists ? oldSnapshot.data() : null,
    newMember: newSnapshot.exists ? newSnapshot.data() : null,
    newAuthUser,
    codeIndex:
      codeSnapshot && codeSnapshot.exists ? codeSnapshot.data() : null,
  };
  validateDryRunState({
    ...state,
    expectedOldOwnerUid: oldUid,
    expectedNewOwnerUid: newUid,
  });
  return state;
}

async function applyMigration({db, admin, args}) {
  const familyId = args["family-id"];
  const oldUid = args["expected-old-owner-uid"];
  const newUid = args["expected-new-owner-uid"];
  const familyRef = db.collection("families").doc(familyId);
  const oldRef = familyRef.collection("members").doc(oldUid);
  const newRef = familyRef.collection("members").doc(newUid);
  const auditRef = familyRef
    .collection("_private_audit")
    .doc(args["migration-id"]);
  const oldTokensQuery = familyRef
    .collection("fcm_tokens")
    .where("uid", "==", oldUid);

  return db.runTransaction(async (transaction) => {
    const familySnapshot = await transaction.get(familyRef);
    const oldSnapshot = await transaction.get(oldRef);
    const newSnapshot = await transaction.get(newRef);
    const auditSnapshot = await transaction.get(auditRef);
    if (auditSnapshot.exists) {
      const audit = auditSnapshot.data();
      if (
        audit.type === "historical-owner-migration" &&
        audit.previousOwnerUid === oldUid &&
        audit.newOwnerUid === newUid &&
        familySnapshot.exists &&
        familySnapshot.data().ownerUid === newUid
      ) {
        return {status: "already-completed", idempotent: true};
      }
      throw new Error("MIGRATION_ID_ALREADY_USED");
    }
    if (!familySnapshot.exists) throw new Error("FAMILY_NOT_FOUND");
    const family = familySnapshot.data();
    const codeRef =
      typeof family.code === "string" && family.code.length > 0
        ? db.collection("family_codes").doc(family.code)
        : null;
    const codeSnapshot = codeRef
      ? await transaction.get(codeRef)
      : null;
    const tokensSnapshot = await transaction.get(oldTokensQuery);
    const actualHash = migrationStateHash({
      familyId,
      family,
      oldMember: oldSnapshot.exists ? oldSnapshot.data() : null,
      newMember: newSnapshot.exists ? newSnapshot.data() : null,
      codeIndex:
        codeSnapshot && codeSnapshot.exists ? codeSnapshot.data() : null,
    });
    if (actualHash !== args["expected-state-hash"]) {
      throw new Error("STATE_CHANGED_SINCE_DRY_RUN");
    }
    if (family.ownerUid !== oldUid) {
      throw new Error("OLD_OWNER_STATE_MISMATCH");
    }

    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    transaction.update(familyRef, {
      ownerUid: newUid,
      schemaVersion: 2,
      migrationStatus: "historical-owner-repaired",
      ownershipUpdatedAt: timestamp,
    });
    transaction.set(oldRef, {
      uid: oldUid,
      role: "parent",
      active: false,
      childId: null,
      ownershipMigratedAt: timestamp,
    }, {merge: true});
    transaction.set(newRef, {
      uid: newUid,
      role: "owner",
      active: true,
      childId: null,
      durableAccount: true,
      ownershipReceivedAt: timestamp,
    }, {merge: true});
    if (
      codeRef &&
      codeSnapshot &&
      codeSnapshot.exists &&
      codeSnapshot.data().familyId === familyId
    ) {
      transaction.set(
        codeRef,
        {ownerUid: newUid, updatedAt: timestamp},
        {merge: true}
      );
    }
    for (const tokenDocument of tokensSnapshot.docs) {
      transaction.set(
        tokenDocument.ref,
        {
          disabled: true,
          disabledReason: "historical-owner-migration",
          disabledAt: timestamp,
        },
        {merge: true}
      );
    }
    transaction.create(auditRef, {
      type: "historical-owner-migration",
      previousOwnerUid: oldUid,
      newOwnerUid: newUid,
      expectedStateHash: actualHash,
      disabledTokenCount: tokensSnapshot.size,
      createdAt: timestamp,
    });
    return {status: "completed", idempotent: false};
  });
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  assertMigrationSafety(args);
  const admin = require("firebase-admin");
  if (admin.apps.length === 0) {
    admin.initializeApp({projectId: REQUIRED_PROJECT});
  }
  const db = admin.firestore();
  const auth = admin.auth();
  const state = await readExactState({db, auth, args});
  const report = anonymizedReport(state);
  if (args["dry-run"]) {
    process.stdout.write(`${JSON.stringify(report)}\n`);
    return;
  }
  const result = await applyMigration({db, admin, args});
  process.stdout.write(`${JSON.stringify({
    status: result.status,
    idempotent: result.idempotent,
    selectedFamily: report.selectedFamily,
  })}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`Migration refusée: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  REQUIRED_PROJECT,
  parseArgs,
  cleanRequiredId,
  assertMigrationSafety,
  migrationStateHash,
  validateDryRunState,
  anonymizedReport,
  readExactState,
  applyMigration,
};
