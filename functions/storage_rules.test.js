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
const {doc, setDoc} = require("firebase/firestore");
const {
  ref,
  uploadBytes,
  getBytes,
  deleteObject,
} = require("firebase/storage");

const PROJECT_ID = "demo-sks-family";
const FAMILY_A = "family-a";
const FAMILY_B = "family-b";
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
let testEnv;

function proofRef(context, familyId, actionId, extension = "jpg") {
  return ref(
    context.storage(),
    `families/${familyId}/actions/${actionId}/proof.${extension}`
  );
}

async function seedFirestore() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, "families", FAMILY_A), {ownerUid: "owner-a"});
    await setDoc(doc(db, "families", FAMILY_B), {ownerUid: "owner-b"});
    const members = [
      [FAMILY_A, "owner-a", "owner", true],
      [FAMILY_A, "parent-a", "parent", true],
      [FAMILY_A, "child-a", "child", true],
      [FAMILY_A, "inactive-a", "parent", false],
      [FAMILY_B, "owner-b", "owner", true],
    ];
    for (const [familyId, uid, role, active] of members) {
      await setDoc(doc(db, "families", familyId, "members", uid), {
        uid,
        role,
        active,
        childId: role === "child" ? "child-1" : null,
      });
    }
  });
}

test.before(async () => {
  assert.equal(PROJECT_ID.startsWith("demo-"), true);
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Le test refuse de contacter un Firestore réel."
  );
  assert.ok(
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
    "Le test refuse de contacter un Storage réel."
  );
  const rules = fs.readFileSync(
    path.join(__dirname, "..", "storage.rules"),
    "utf8"
  );
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    storage: {rules},
  });
});

test.beforeEach(async () => {
  await testEnv.clearStorage();
  await seedFirestore();
});

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test("un parent actif peut ajouter, lire et remplacer une preuve valide", async () => {
  const parent = testEnv.authenticatedContext("parent-a");
  const target = proofRef(parent, FAMILY_A, "action-1");
  await assertSucceeds(
    uploadBytes(target, JPEG, {contentType: "image/jpeg"})
  );
  await assertSucceeds(getBytes(target));
  await assertSucceeds(
    uploadBytes(target, JPEG, {contentType: "image/jpeg"})
  );
  await assertSucceeds(deleteObject(target));
});

test("une preuve devient immuable dès que l'action serveur existe", async () => {
  const parent = testEnv.authenticatedContext("parent-a");
  const target = proofRef(parent, FAMILY_A, "action-locked");
  await assertSucceeds(
    uploadBytes(target, JPEG, {contentType: "image/jpeg"})
  );
  await testEnv.withSecurityRulesDisabled(async (context) => {
    await setDoc(
      doc(
        context.firestore(),
        "families",
        FAMILY_A,
        "history",
        "action-locked"
      ),
      {id: "action-locked"}
    );
  });
  await assertSucceeds(getBytes(target));
  await assertFails(
    uploadBytes(target, JPEG, {contentType: "image/jpeg"})
  );
  await assertFails(deleteObject(target));
});

test("enfant, membre inactif et personne extérieure ne peuvent pas écrire", async () => {
  for (const uid of ["child-a", "inactive-a", "outsider"]) {
    await assertFails(
      uploadBytes(
        proofRef(testEnv.authenticatedContext(uid), FAMILY_A, `action-${uid}`),
        JPEG,
        {contentType: "image/jpeg"}
      )
    );
  }
});

test("format, nom et taille invalides sont refusés", async () => {
  const parent = testEnv.authenticatedContext("parent-a");
  await assertFails(
    uploadBytes(
      proofRef(parent, FAMILY_A, "bad-type"),
      new Uint8Array([1, 2, 3]),
      {contentType: "text/plain"}
    )
  );
  await assertFails(
    uploadBytes(
      ref(
        parent.storage(),
        `families/${FAMILY_A}/actions/bad-name/user-name.jpg`
      ),
      JPEG,
      {contentType: "image/jpeg"}
    )
  );
  await assertFails(
    uploadBytes(
      proofRef(parent, FAMILY_A, "too-large"),
      new Uint8Array(5 * 1024 * 1024 + 1),
      {contentType: "image/jpeg"}
    )
  );
});

test("une autre famille ne peut ni lire ni écrire la preuve", async () => {
  const ownerB = testEnv.authenticatedContext("owner-b");
  const targetB = proofRef(ownerB, FAMILY_B, "action-b");
  await assertSucceeds(
    uploadBytes(targetB, JPEG, {contentType: "image/jpeg"})
  );

  const parentA = testEnv.authenticatedContext("parent-a");
  await assertFails(
    getBytes(proofRef(parentA, FAMILY_B, "action-b"))
  );
  await assertFails(
    uploadBytes(
      proofRef(parentA, FAMILY_B, "forged"),
      JPEG,
      {contentType: "image/jpeg"}
    )
  );
});

test("les membres actifs de la famille peuvent lire la preuve", async () => {
  const parent = testEnv.authenticatedContext("parent-a");
  await assertSucceeds(
    uploadBytes(
      proofRef(parent, FAMILY_A, "visible"),
      JPEG,
      {contentType: "image/jpeg"}
    )
  );
  const child = testEnv.authenticatedContext("child-a");
  await assertSucceeds(getBytes(proofRef(child, FAMILY_A, "visible")));
});
