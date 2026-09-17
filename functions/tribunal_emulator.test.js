"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const admin = require("firebase-admin");
const {initializeTestEnvironment, assertFails, assertSucceeds} = require("@firebase/rules-unit-testing");
const {doc, getDoc, setDoc} = require("firebase/firestore");
const {createSecureChildOperationFunctions} = require("./secure_child_operations");

// Ce test ne doit jamais accéder à une base distante.
if (!process.env.FIRESTORE_EMULATOR_HOST) throw new Error("Local Firestore emulator required");
const projectId = "demo-sks-family";
let env, app, db, call;
class HttpsError extends Error {
  constructor(code, message) { super(message); this.code = code; }
}
test.before(async () => {
  env = await initializeTestEnvironment({projectId,
    firestore: {rules: fs.readFileSync(path.join(__dirname, "../firestore.rules"), "utf8")}});
  app = admin.initializeApp({projectId}, "tribunal-local-test");
  db = app.firestore();
  call = createSecureChildOperationFunctions({db, admin,
    functions: {https: {HttpsError, onCall: fn => fn}}}).performFamilyOperation;
});
test.after(async () => { await env?.cleanup(); await app?.delete(); });

test("enfant -> callable -> affaire lisible par parent, sans ouvrir l'écriture directe", async () => {
  const familyId = `tribunal-${process.pid}`;
  const family = db.collection("families").doc(familyId);
  await family.set({ownerUid: "owner"});
  await family.collection("members").doc("owner").set({uid: "owner", role: "owner", active: true});
  await family.collection("members").doc("child").set({uid: "child", role: "child", childId: "c1", active: true});
  await family.collection("children").doc("c1").set({id: "c1", name: "Test 1"});
  await family.collection("children").doc("c2").set({id: "c2", name: "Test 2"});
  const payload = {familyId, operationId: "test-case", operation: "tribunal_create",
    tribunal: {title: "Affaire test", description: "Test local", plaintiffId: "c1", accusedId: "c2"}};
  const auth = {auth: {uid: "child", token: {}}};
  const [first, second] = await Promise.all([call(payload, auth), call(payload, auth)]);
  assert.equal(first.caseId, second.caseId);
  assert.equal([first.idempotent, second.idempotent].filter(Boolean).length, 1);
  assert.equal((await family.collection("tribunal").get()).size, 1);
  const ownerDb = env.authenticatedContext("owner").firestore();
  const ownerRead = await assertSucceeds(getDoc(doc(ownerDb, "families", familyId, "tribunal", "test-case")));
  assert.equal(ownerRead.data().status, "filed");
  const childDb = env.authenticatedContext("child").firestore();
  await assertSucceeds(getDoc(doc(childDb, "families", familyId, "tribunal", "test-case")));
  await assertFails(setDoc(doc(childDb, "families", familyId, "tribunal", "forged"), first.tribunal));
  await assertFails(getDoc(doc(env.authenticatedContext("outsider").firestore(),
    "families", familyId, "tribunal", "test-case")));
  await assert.rejects(call({...payload, operationId: "spoofed", tribunal: {
    ...payload.tribunal, plaintiffId: "c2", accusedId: "c1"}}, auth), {code: "permission-denied"});
});
