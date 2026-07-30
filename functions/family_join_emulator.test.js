"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  OWNER_AUTH_CODES,
} = require("./family_owner_authorization");
const {
  createFamilyJoinFunctions,
} = require("./family_join");

const PROJECT_ID = "demo-sks-family";

class TestHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

const fakeFunctions = {
  https: {
    HttpsError: TestHttpsError,
    onCall: (handler) => handler,
  },
};

let app;
let db;
let approveFamilyJoin;
let sequence = 0;

function nextFamilyId(label) {
  sequence += 1;
  return `owner-auth-${label}-${process.pid}-${sequence}`;
}

async function seedApproval({
  label,
  ownerUid = "owner-a",
  familyData = {},
  reviewerUid = ownerUid,
  reviewerMember = {
    uid: reviewerUid,
    role: "owner",
    active: true,
    childId: null,
  },
  requesterUid = "requester-parent",
  requestData = {},
}) {
  const familyId = nextFamilyId(label);
  const familyRef = db.collection("families").doc(familyId);
  const storedFamily = {
    schemaVersion: 2,
    migrationStatus: "native",
    code: `T${sequence}EST`,
    memberCount: 1,
    ...familyData,
  };

  if (ownerUid != null) {
    storedFamily.ownerUid = ownerUid;
  }

  await familyRef.set(storedFamily);

  if (reviewerMember) {
    await familyRef
      .collection("members")
      .doc(reviewerUid)
      .set(reviewerMember);
  }

  await familyRef
    .collection("join_requests")
    .doc(requesterUid)
    .set({
      requesterUid,
      requestedRole: "parent",
      status: "sent",
      ...requestData,
    });

  return {
    familyId,
    familyRef,
    reviewerUid,
    requesterUid,
  };
}

async function expectOwnerRefusal(promise, reason) {
  await assert.rejects(
    promise,
    (error) =>
      error instanceof TestHttpsError &&
      error.details &&
      error.details.reason === reason
  );
}

test.before(() => {
  assert.equal(PROJECT_ID, "demo-sks-family");
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Le test refuse de contacter un Firestore réel."
  );

  app = admin.initializeApp(
    {projectId: PROJECT_ID},
    `family-owner-tests-${process.pid}`
  );
  db = admin.firestore(app);
  approveFamilyJoin = createFamilyJoinFunctions({
    functions: fakeFunctions,
    admin,
    db,
  }).approveFamilyJoin;
});

test.after(async () => {
  if (app) await app.delete();
});

test("propriétaire moderne autorisé", async () => {
  const seeded = await seedApproval({label: "modern"});

  const result = await approveFamilyJoin(
    {
      familyId: seeded.familyId,
      requesterUid: seeded.requesterUid,
    },
    {auth: {uid: seeded.reviewerUid}}
  );

  assert.equal(result.status, "accepted");
  assert.equal(result.role, "parent");
  const member = await seeded.familyRef
    .collection("members")
    .doc(seeded.requesterUid)
    .get();
  assert.equal(member.data().uid, seeded.requesterUid);
  assert.equal(member.data().role, "parent");
});

test("propriétaire historique prouvé et document membre réparé", async () => {
  const seeded = await seedApproval({
    label: "historical",
    familyData: {
      schemaVersion: 1,
      migrationStatus: "legacy-ownerUid",
    },
    reviewerMember: null,
  });

  await approveFamilyJoin(
    {
      familyId: seeded.familyId,
      requesterUid: seeded.requesterUid,
    },
    {auth: {uid: seeded.reviewerUid}}
  );

  const repairedOwner = await seeded.familyRef
    .collection("members")
    .doc(seeded.reviewerUid)
    .get();
  assert.equal(repairedOwner.data().uid, seeded.reviewerUid);
  assert.equal(repairedOwner.data().role, "owner");
  assert.equal(repairedOwner.data().active, true);
  assert.equal(
    repairedOwner.data().ownerAuthorizationRepair,
    OWNER_AUTH_CODES.MEMBER_REPAIRED_MISSING
  );
});

test("parent actif refusé", async () => {
  const seeded = await seedApproval({
    label: "active-parent",
    ownerUid: "owner-a",
    reviewerUid: "parent-a",
    reviewerMember: {
      uid: "parent-a",
      role: "parent",
      active: true,
    },
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.OWNER_UID_MISMATCH
  );
});

test("membre inactif refusé", async () => {
  const seeded = await seedApproval({
    label: "inactive",
    reviewerMember: {
      uid: "owner-a",
      role: "owner",
      active: false,
    },
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.MEMBER_INACTIVE
  );
});

test("UID membre incohérent refusé", async () => {
  const seeded = await seedApproval({
    label: "mismatched-member",
    reviewerMember: {
      uid: "another-uid",
      role: "owner",
      active: true,
    },
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.MEMBER_UID_MISMATCH
  );
});

test("propriétaire d'une autre famille refusé", async () => {
  const seeded = await seedApproval({
    label: "other-family",
    ownerUid: "owner-b",
    reviewerUid: "owner-a",
    reviewerMember: {
      uid: "owner-a",
      role: "owner",
      active: true,
    },
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.OWNER_UID_MISMATCH
  );
});

test("tentative d'usurpation du rôle envoyée par le client refusée", async () => {
  const seeded = await seedApproval({
    label: "spoofed-role",
    ownerUid: "owner-a",
    reviewerUid: "parent-a",
    reviewerMember: {
      uid: "parent-a",
      role: "parent",
      active: true,
    },
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
        reviewerRole: "owner",
        isParentMode: true,
        pinValidated: true,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.OWNER_UID_MISMATCH
  );
});

test("double approbation idempotente", async () => {
  const seeded = await seedApproval({label: "idempotent"});
  const payload = {
    familyId: seeded.familyId,
    requesterUid: seeded.requesterUid,
  };
  const context = {auth: {uid: seeded.reviewerUid}};

  await approveFamilyJoin(payload, context);
  const second = await approveFamilyJoin(payload, context);

  assert.equal(second.status, "accepted");
  assert.equal(second.role, "parent");
  const family = await seeded.familyRef.get();
  assert.equal(family.data().memberCount, 2);
});

test("format ownerId seul refusé sans promotion automatique", async () => {
  const seeded = await seedApproval({
    label: "owner-id-only",
    ownerUid: null,
    reviewerUid: "owner-a",
    familyData: {
      ownerId: "owner-a",
      schemaVersion: 1,
    },
    reviewerMember: null,
  });

  await expectOwnerRefusal(
    approveFamilyJoin(
      {
        familyId: seeded.familyId,
        requesterUid: seeded.requesterUid,
      },
      {auth: {uid: seeded.reviewerUid}}
    ),
    OWNER_AUTH_CODES.HISTORICAL_FORMAT
  );

  const ownerMember = await seeded.familyRef
    .collection("members")
    .doc(seeded.reviewerUid)
    .get();
  assert.equal(ownerMember.exists, false);
});

test("utilisateur non authentifié refusé avec diagnostic dédié", async () => {
  await expectOwnerRefusal(
    approveFamilyJoin(
      {familyId: "family-test", requesterUid: "requester"},
      {}
    ),
    OWNER_AUTH_CODES.UNAUTHENTICATED
  );
});
