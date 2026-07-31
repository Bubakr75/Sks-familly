"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "demo-sks-family";
const FAMILY_A = "family-a";
const FAMILY_B = "family-b";
const CHILD_1 = "child-1";
const CHILD_2 = "child-2";

let testEnv;

function walletRef(db, familyId, childId) {
  return doc(db, "families", familyId, "wallets", childId);
}

function operationRef(db, familyId, childId, operationId = "operation-1") {
  return doc(
    db,
    "families",
    familyId,
    "wallets",
    childId,
    "operations",
    operationId
  );
}

function operationsRef(db, familyId, childId) {
  return collection(
    db,
    "families",
    familyId,
    "wallets",
    childId,
    "operations"
  );
}

async function seedFirestore() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const now = new Date("2026-07-28T12:00:00.000Z");

    await setDoc(doc(db, "families", FAMILY_A), {
      ownerUid: "owner-a",
    });
    await setDoc(doc(db, "families", FAMILY_B), {
      ownerUid: "owner-b",
    });

    const members = [
      ["owner-a", {uid: "owner-a", role: "owner", active: true}],
      ["parent-a", {uid: "parent-a", role: "parent", active: true}],
      [
        "child-a",
        {uid: "child-a", role: "child", childId: CHILD_1, active: true},
      ],
      [
        "child-b",
        {uid: "child-b", role: "child", childId: CHILD_2, active: true},
      ],
      [
        "mismatched",
        {uid: "another-uid", role: "parent", active: true},
      ],
      [
        "inactive",
        {uid: "inactive", role: "parent", active: false},
      ],
    ];
    for (const [uid, data] of members) {
      await setDoc(
        doc(db, "families", FAMILY_A, "members", uid),
        data
      );
    }
    await setDoc(
      doc(db, "families", FAMILY_B, "members", "owner-b"),
      {uid: "owner-b", role: "owner", active: true}
    );

    for (const childId of [CHILD_1, CHILD_2]) {
      await setDoc(doc(db, "families", FAMILY_A, "children", childId), {
        name: childId,
      });
      await setDoc(walletRef(db, FAMILY_A, childId), {
        childId,
        balance: 20,
        createdAt: now,
        updatedAt: now,
      });
      await setDoc(operationRef(db, FAMILY_A, childId), {
        childId,
        type: "credit",
        amount: 20,
        delta: 20,
        reason: "Initialisation",
        actorUid: "owner-a",
        balanceAfter: 20,
        createdAt: now,
      });
    }

    await setDoc(doc(db, "families", FAMILY_B, "children", CHILD_1), {
      name: CHILD_1,
    });
    await setDoc(walletRef(db, FAMILY_B, CHILD_1), {
      childId: CHILD_1,
      balance: 99,
      createdAt: now,
      updatedAt: now,
    });
    await setDoc(operationRef(db, FAMILY_B, CHILD_1), {
      childId: CHILD_1,
      type: "credit",
      amount: 99,
      delta: 99,
      reason: "Autre famille",
      actorUid: "owner-b",
      balanceAfter: 99,
      createdAt: now,
    });
  });
}

test.before(async () => {
  assert.equal(PROJECT_ID, "demo-sks-family");
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST absent : le test refuse de contacter Firestore réel."
  );
  const rules = fs.readFileSync(
    path.join(__dirname, "..", "firestore.rules"),
    "utf8"
  );
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules},
  });
});

test.beforeEach(seedFirestore);

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test("owner reads wallet and operations in the owned family", async () => {
  const db = testEnv.authenticatedContext("owner-a").firestore();
  await assertSucceeds(getDoc(walletRef(db, FAMILY_A, CHILD_1)));
  await assertSucceeds(getDoc(operationRef(db, FAMILY_A, CHILD_1)));
  await assertSucceeds(getDocs(operationsRef(db, FAMILY_A, CHILD_1)));
});

test("active parent with matching member.uid reads wallet and operations", async () => {
  const db = testEnv.authenticatedContext("parent-a").firestore();
  await assertSucceeds(getDoc(walletRef(db, FAMILY_A, CHILD_1)));
  await assertSucceeds(getDoc(operationRef(db, FAMILY_A, CHILD_1)));
  await assertSucceeds(getDocs(operationsRef(db, FAMILY_A, CHILD_1)));
});

test("child reads only the mapped wallet and operations", async () => {
  const db = testEnv.authenticatedContext("child-a").firestore();
  await assertSucceeds(getDoc(walletRef(db, FAMILY_A, CHILD_1)));
  await assertSucceeds(getDocs(operationsRef(db, FAMILY_A, CHILD_1)));
  await assertFails(getDoc(walletRef(db, FAMILY_A, CHILD_2)));
  await assertFails(getDocs(operationsRef(db, FAMILY_A, CHILD_2)));
});

test("other child, mismatched UID, inactive member and outsider are denied", async () => {
  for (const uid of ["child-b", "mismatched", "inactive", "outsider"]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDoc(walletRef(db, FAMILY_A, CHILD_1)));
    await assertFails(getDoc(operationRef(db, FAMILY_A, CHILD_1)));
    await assertFails(getDocs(operationsRef(db, FAMILY_A, CHILD_1)));
  }
});

test("member of one family cannot read another family", async () => {
  const db = testEnv.authenticatedContext("owner-a").firestore();
  await assertFails(getDoc(walletRef(db, FAMILY_B, CHILD_1)));
  await assertFails(getDoc(operationRef(db, FAMILY_B, CHILD_1)));
  await assertFails(getDocs(operationsRef(db, FAMILY_B, CHILD_1)));
});

test("unauthenticated user cannot read wallets or operations", async () => {
  const db = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(walletRef(db, FAMILY_A, CHILD_1)));
  await assertFails(getDoc(operationRef(db, FAMILY_A, CHILD_1)));
  await assertFails(getDocs(operationsRef(db, FAMILY_A, CHILD_1)));
});

test("all clients are denied direct wallet and operation writes", async () => {
  const contexts = [
    testEnv.authenticatedContext("owner-a"),
    testEnv.authenticatedContext("parent-a"),
    testEnv.authenticatedContext("child-a"),
    testEnv.authenticatedContext("outsider"),
    testEnv.unauthenticatedContext(),
  ];

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(
      setDoc(walletRef(db, FAMILY_A, "new-child"), {
        childId: "new-child",
        balance: 1,
      })
    );
    await assertFails(
      updateDoc(walletRef(db, FAMILY_A, CHILD_1), {balance: 999})
    );
    await assertFails(deleteDoc(walletRef(db, FAMILY_A, CHILD_1)));

    await assertFails(
      setDoc(operationRef(db, FAMILY_A, CHILD_1, "new-operation"), {
        childId: CHILD_1,
        amount: 1,
      })
    );
    await assertFails(
      updateDoc(operationRef(db, FAMILY_A, CHILD_1), {amount: 999})
    );
    await assertFails(deleteDoc(operationRef(db, FAMILY_A, CHILD_1)));
  }
});
