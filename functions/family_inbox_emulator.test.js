"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");
const admin = require("firebase-admin");
const {createFamilyInboxFunctions} = require("./family_inbox");
const {createFamilyJoinFunctions} = require("./family_join");
class HttpsError extends Error {
  constructor(code, message, details) { super(message); this.code = code; this.details = details; }
}
let app, db, inbox, family;
const verified = {email_verified: true, firebase: {sign_in_provider: "password"}};
const context = (uid, token = {}) => ({auth: {uid, token}});
test.before(async () => {
  assert.match(process.env.FIRESTORE_EMULATOR_HOST || "", /^(127\.0\.0\.1|localhost):[0-9]+$/);
  app = admin.initializeApp({projectId: "demo-sks-family"}, "inbox-test");
  db = app.firestore();
  inbox = createFamilyInboxFunctions({admin, db, functions: {https: {HttpsError, onCall: f => f}}});
});
test.beforeEach(async () => {
  family = db.collection("families").doc();
  await family.set({ownerUid: "owner"});
  for (const [uid, role, active, storedUid] of [
    ["owner", "owner", true, "owner"], ["parent", "parent", true, "parent"],
    ["manager", "manager", true, "manager"], ["admin", "familyAdmin", true, "admin"],
    ["child", "child", true, "child"], ["inactive", "parent", false, "inactive"],
    ["mismatch", "parent", true, "parent"], ["false-owner", "owner", true, "false-owner"],
  ]) await family.collection("members").doc(uid).set({uid: storedUid, role, active, childId: "c1"});
  await family.collection("requests").doc("purchase").set({status: "pending", type: "boutique", amount: 25, extra: {purchaseId: "purchase"}});
  await family.collection("purchases").doc("purchase").set({status: "pending", cost: 25});
  await family.collection("history").doc("event").set({amount: -25});
  await family.collection("wallets").doc("c1").set({balance: 75});
  await family.collection("join_requests").doc("iphone").set({requesterUid: "iphone", status: "sent", deviceName: "iPhone test", deviceId: "iphone-device"});
});
test.after(async () => { await app?.delete(); });
const dismiss = (uid, token) => inbox.dismissFamilyNotification({familyId: family.id, notificationId: "purchase"}, context(uid, token));
test("masquage concurrent et répété idempotent, événements métier conservés", async () => {
  const collections = ["purchases", "history", "wallets", "join_requests"];
  const before = await Promise.all(collections.map(async name => (await family.collection(name).get()).docs.map(d => d.data())));
  await Promise.all([dismiss("parent"), dismiss("parent")]);
  const first = (await family.collection("requests").doc("purchase").get()).data();
  await dismiss("parent");
  assert.deepEqual((await family.collection("requests").doc("purchase").get()).data(), first);
  assert.deepEqual(first.dismissedBy, ["parent"]);
  assert.equal(first.status, "pending"); assert.equal(first.amount, 25);
  assert.deepEqual(first.extra, {purchaseId: "purchase"});
  const after = await Promise.all(collections.map(async name => (await family.collection(name).get()).docs.map(d => d.data())));
  assert.deepEqual(after, before);
  await dismiss("owner");
  assert.deepEqual(new Set((await family.collection("requests").doc("purchase").get()).data().dismissedBy), new Set(["parent", "owner"]));
});
test("tous les rôles de masquage respectent les droits serveur", async () => {
  for (const uid of ["owner", "parent", "manager", "admin"]) await dismiss(uid, verified);
  for (const uid of ["child", "inactive", "mismatch", "false-owner", "outsider", "manager", "admin"]) {
    await assert.rejects(dismiss(uid), e => e.code === "permission-denied");
  }
  await assert.rejects(inbox.dismissFamilyNotification({familyId: family.id, notificationId: "purchase"}, {}), e => e.code === "unauthenticated");
});
test("identifiants invalides, notification absente et capacité contrôlés", async () => {
  for (const notificationId of ["", "a/b", "x".repeat(129), 42]) {
    await assert.rejects(inbox.dismissFamilyNotification({familyId: family.id, notificationId}, context("parent")), e => e.code === "invalid-argument");
  }
  await assert.rejects(inbox.dismissFamilyNotification({familyId: family.id, notificationId: "missing"}, context("parent")), e => e.code === "not-found");
  const ref = family.collection("requests").doc("purchase");
  await ref.update({dismissedBy: Array.from({length: 100}, (_, i) => "test-" + i)});
  await assert.rejects(dismiss("parent"), e => e.code === "resource-exhausted");
  await ref.update({dismissedBy: ["parent", ...Array.from({length: 99}, (_, i) => "test-" + i)]});
  await dismiss("parent");
});
test("le parent actif marque la demande iPhone reçue sans l'approuver", async () => {
  await inbox.markFamilyInboxRead({familyId: family.id}, context("parent"));
  const record = (await family.collection("join_requests").doc("iphone").get()).data();
  assert.equal(record.status, "received"); assert.deepEqual(record.readBy, ["parent"]);
  assert.equal(record.requesterUid, "iphone");
});
function joinTrigger(sends, failPush = false) {
  const fakeFirestore = Object.assign(() => db, admin.firestore);
  const fakeAdmin = {initializeApp() {}, firestore: fakeFirestore,
    auth: () => ({getUser: async uid => ({disabled: false, emailVerified: ["manager", "admin"].includes(uid), providerData: [{providerId: "password"}]})}),
    storage: () => ({}), messaging: () => ({sendEachForMulticast: async message => {
      sends.push(message);
      if (failPush) throw new Error("FCM indisponible (test local)");
      return {successCount: message.tokens.length, failureCount: 0, responses: message.tokens.map(() => ({success: true}))};
    }})};
  const module = {exports: {}};
  // Même contexte Promise que le SDK Firestore, sans charger le vrai Admin.
  const load = vm.runInThisContext(
    "(function(require, module, exports) {\n" +
      fs.readFileSync(path.join(__dirname, "index.js"), "utf8") + "\n})",
    {filename: path.join(__dirname, "index.js")}
  );
  load(name => name === "firebase-admin" ? fakeAdmin : require(name), module, module.exports);
  return module.exports.onJoinRequestCreated;
}
const triggerContext = () => ({eventId: "local-event-" + family.id, params: {familyId: family.id, requestId: "iphone"}});

test("le vrai déclencheur iPhone cible les parents et gestionnaires vérifiés, exclut les profils interdits", async () => {
  const sends = [];
  await family.collection("members").doc("unverified").set({uid: "unverified", role: "manager", active: true});
  for (const uid of ["owner", "parent", "manager", "admin", "unverified", "child", "inactive", "mismatch", "false-owner", "outsider"]) {
    await family.collection("fcm_tokens").doc(uid).set({uid, token: "test-token-" + uid});
  }
  await family.collection("fcm_tokens").doc("iphone-device").set({uid: "parent", token: "test-requester"});
  await family.collection("fcm_tokens").doc("disabled").set({uid: "parent", token: "test-disabled", disabled: true});
  const snap = await family.collection("join_requests").doc("iphone").get();
  await joinTrigger(sends).run(snap, triggerContext());
  assert.equal(sends.length, 1);
  assert.deepEqual(Array.from(sends[0].tokens).sort(), ["test-token-admin", "test-token-manager", "test-token-owner", "test-token-parent"]);
  assert.equal(sends[0].data.type, "join_request");
  assert.equal(sends[0].data.sender, "iphone-device");
  assert.deepEqual(Object.keys(sends[0].data).sort(), ["familyId", "requestId", "sender", "type"]);
  assert.equal(sends[0].notification.body.includes("iPhone test"), false);
});

test("rejeux simultanés du déclencheur et tokens dupliqués : un seul envoi", async () => {
  const sends = [];
  for (const id of ["parent-1", "parent-2"]) {
    await family.collection("fcm_tokens").doc(id).set({uid: "parent", token: "same-token"});
  }
  const trigger = joinTrigger(sends);
  const snap = await family.collection("join_requests").doc("iphone").get();
  await Promise.all([trigger.run(snap, triggerContext()), trigger.run(snap, triggerContext())]);
  await trigger.run(snap, triggerContext());
  assert.equal(sends.length, 1);
  assert.deepEqual(Array.from(sends[0].tokens), ["same-token"]);
});

test("une panne push conserve la demande iPhone dans la boîte parentale", async () => {
  const sends = [];
  await family.collection("fcm_tokens").doc("parent").set({uid: "parent", token: "test-token"});
  const ref = family.collection("join_requests").doc("iphone");
  const trigger = joinTrigger(sends, true);
  const snap = await ref.get();
  await trigger.run(snap, triggerContext());
  await trigger.run(snap, triggerContext());
  assert.equal(sends.length, 1);
  assert.equal((await ref.get()).data().status, "sent");
  await inbox.markFamilyInboxRead({familyId: family.id}, context("parent"));
  assert.equal((await ref.get()).data().status, "received");
  assert.deepEqual((await ref.get()).data().readBy, ["parent"]);
});

test("requestFamilyJoin répété conserve une seule demande et sa date", async () => {
  const code = family.id.toUpperCase();
  await family.update({code, schemaVersion: 2});
  const joins = createFamilyJoinFunctions({admin, db, functions: {https: {HttpsError, onCall: f => f}}});
  const uid = "requester-" + family.id;
  const data = {code, deviceId: "local-iphone", deviceName: "iPhone test", requestedRole: "parent"};
  const first = await joins.requestFamilyJoin(data, context(uid));
  const before = (await family.collection("join_requests").doc(uid).get()).data();
  const again = await joins.requestFamilyJoin(data, context(uid));
  assert.equal(first.alreadyPending, false);
  assert.equal(again.alreadyPending, true);
  assert.equal(first.requestId, again.requestId);
  assert.deepEqual((await family.collection("join_requests").doc(uid).get()).data(), before);
});
