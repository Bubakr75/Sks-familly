"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  createFamilyOwnershipFunctions,
  hashRecoverySecret,
  emailHash,
} = require("./family_ownership");

const PROJECT_ID = "demo-sks-family";
const NOW_SECONDS = 2000000000;
let app;
let db;
let api;
let sequence = 0;

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

function durableContext(uid, email = "owner@example.test") {
  return {
    auth: {
      uid,
      token: {
        email,
        email_verified: true,
        auth_time: NOW_SECONDS - 30,
        firebase: {sign_in_provider: "password"},
      },
    },
  };
}

function verifiedUser(uid) {
  return {
    uid,
    emailVerified: true,
    providerData: [{providerId: "password"}],
  };
}

async function seedFamily(label) {
  sequence += 1;
  const familyId = `ownership-${label}-${process.pid}-${sequence}`;
  const familyRef = db.collection("families").doc(familyId);
  const code = `C${String(sequence).padStart(5, "0")}`;
  await familyRef.set({
    ownerUid: "owner-a",
    code,
    schemaVersion: 2,
  });
  await familyRef.collection("members").doc("owner-a").set({
    uid: "owner-a",
    role: "owner",
    active: true,
  });
  await familyRef.collection("members").doc("parent-a").set({
    uid: "parent-a",
    role: "parent",
    active: true,
  });
  await db.collection("family_codes").doc(code).set({
    familyId,
    ownerUid: "owner-a",
    code,
  });
  return {familyId, familyRef, code};
}

test.before(() => {
  assert.equal(PROJECT_ID, "demo-sks-family");
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Le test refuse de contacter un Firestore réel."
  );
  app = admin.initializeApp(
    {projectId: PROJECT_ID},
    `family-ownership-tests-${process.pid}`
  );
  db = admin.firestore(app);
  api = createFamilyOwnershipFunctions({
    functions: fakeFunctions,
    admin,
    db,
    auth: {getUser: async (uid) => verifiedUser(uid)},
    nowSeconds: () => NOW_SECONDS,
  });
});

test.after(async () => {
  if (app) await app.delete();
});

test("transfert atomique puis double appel idempotent", async () => {
  const seeded = await seedFamily("transfer");
  const payload = {
    familyId: seeded.familyId,
    targetMemberId: "parent-a",
    operationId: "transfer-operation",
    previousOwnerRole: "manager",
    confirmation: "TRANSFERER LA PROPRIETE",
  };
  const context = durableContext("owner-a");
  const first = await api.transferFamilyOwnership(payload, context);
  const second = await api.transferFamilyOwnership(payload, context);
  assert.equal(first.idempotent, false);
  assert.equal(second.idempotent, true);

  const [family, oldOwner, newOwner, code] = await Promise.all([
    seeded.familyRef.get(),
    seeded.familyRef.collection("members").doc("owner-a").get(),
    seeded.familyRef.collection("members").doc("parent-a").get(),
    db.collection("family_codes").doc(seeded.code).get(),
  ]);
  assert.equal(family.data().ownerUid, "parent-a");
  assert.equal(oldOwner.data().role, "manager");
  assert.equal(newOwner.data().role, "owner");
  assert.equal(code.data().ownerUid, "parent-a");
});

test("un parent ordinaire ne peut pas transférer la propriété", async () => {
  const seeded = await seedFamily("parent-denied");
  await assert.rejects(
    api.transferFamilyOwnership(
      {
        familyId: seeded.familyId,
        targetMemberId: "owner-a",
        operationId: "forged-transfer",
        previousOwnerRole: "parent",
        confirmation: "TRANSFERER LA PROPRIETE",
      },
      durableContext("parent-a", "parent@example.test")
    ),
    (error) => error.code === "failed-precondition" ||
      error.code === "permission-denied"
  );
  assert.equal((await seeded.familyRef.get()).data().ownerUid, "owner-a");
});

test("récupération valide atomique, puis preuve inutilisable", async () => {
  const seeded = await seedFamily("recovery");
  const secret = "A".repeat(44);
  const secured = hashRecoverySecret(secret, Buffer.alloc(16, 3));
  await seeded.familyRef.collection("_private_recovery").doc("current").set({
    ...secured,
    ownerUid: "owner-a",
    ownerEmailHash: emailHash("owner@example.test"),
    expiresAt: admin.firestore.Timestamp.fromMillis(
      (NOW_SECONDS + 60) * 1000
    ),
    revoked: false,
    used: false,
  });
  const payload = {
    familyId: seeded.familyId,
    operationId: "recovery-operation",
    recoveryCode: secret,
    confirmation: "RECUPERER LA PROPRIETE",
  };
  const context = durableContext("replacement-owner");
  const first = await api.recoverFamilyOwnership(payload, context);
  const second = await api.recoverFamilyOwnership(payload, context);
  assert.equal(first.idempotent, false);
  assert.equal(second.idempotent, true);
  assert.equal(
    (await seeded.familyRef.get()).data().ownerUid,
    "replacement-owner"
  );
  assert.equal(
    (await seeded.familyRef
      .collection("_private_recovery")
      .doc("current")
      .get()).data().used,
    true
  );

  await assert.rejects(
    api.recoverFamilyOwnership(
      {...payload, operationId: "recovery-reuse"},
      durableContext("another-owner")
    ),
    (error) => error.code === "permission-denied"
  );
});

test("récupération invalide ou expirée refusée sans écriture", async () => {
  for (const [label, expiresAt, secret] of [
    ["invalid", NOW_SECONDS + 60, "B".repeat(44)],
    ["expired", NOW_SECONDS - 1, "A".repeat(44)],
  ]) {
    const seeded = await seedFamily(label);
    const storedSecret = "A".repeat(44);
    const secured = hashRecoverySecret(storedSecret, Buffer.alloc(16, 4));
    await seeded.familyRef.collection("_private_recovery").doc("current").set({
      ...secured,
      ownerUid: "owner-a",
      ownerEmailHash: emailHash("owner@example.test"),
      expiresAt: admin.firestore.Timestamp.fromMillis(expiresAt * 1000),
      revoked: false,
      used: false,
    });
    await assert.rejects(
      api.recoverFamilyOwnership(
        {
          familyId: seeded.familyId,
          operationId: `recovery-${label}`,
          recoveryCode: secret,
          confirmation: "RECUPERER LA PROPRIETE",
        },
        durableContext("replacement-owner")
      ),
      (error) => error.code === "permission-denied"
    );
    assert.equal((await seeded.familyRef.get()).data().ownerUid, "owner-a");
  }
});
