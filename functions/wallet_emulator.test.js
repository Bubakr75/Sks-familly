"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");
const {createWalletFunctions} = require("./wallet");

let app;
let db;
let adjustWallet;
let reverseWalletOperation;
let sequence = 0;

class TestHttpsError extends Error {
  constructor(code, message) {
    super(message);
    this.code = code;
  }
}
const fakeFunctions = {https: {
  HttpsError: TestHttpsError,
  onCall: (handler) => handler,
}};
const context = (uid) => ({auth: {uid, token: {}}});

async function seed(label) {
  const familyId = `wallet-reversal-${label}-${process.pid}-${++sequence}`;
  const familyRef = db.collection("families").doc(familyId);
  await familyRef.set({ownerUid: "owner-a", schemaVersion: 2});
  await Promise.all([
    familyRef.collection("members").doc("parent-a").set({
      uid: "parent-a", role: "parent", active: true,
    }),
    familyRef.collection("members").doc("child-user").set({
      uid: "child-user", role: "child", active: true, childId: "child-a",
    }),
    familyRef.collection("members").doc("inactive-a").set({
      uid: "inactive-a", role: "parent", active: false,
    }),
    familyRef.collection("children").doc("child-a").set({
      id: "child-a", name: "A", points: 100,
    }),
    familyRef.collection("children").doc("child-b").set({
      id: "child-b", name: "B", points: 70,
    }),
  ]);
  return {familyId, familyRef};
}

test.before(() => {
  assert.ok(process.env.FIRESTORE_EMULATOR_HOST,
    "Le test refuse de contacter un Firestore réel.");
  app = admin.initializeApp(
    {projectId: "demo-sks-family"},
    `wallet-${process.pid}`
  );
  db = admin.firestore(app);
  const fns = createWalletFunctions({functions: fakeFunctions, admin, db});
  adjustWallet = fns.adjustWallet;
  reverseWalletOperation = fns.reverseWalletOperation;
});
test.after(async () => app.delete());

test("débit rend exactement les points et écrit l’historique", async () => {
  const {familyId, familyRef} = await seed("debit");
  await adjustWallet({familyId, childId: "child-a", operationId: "credit-1",
    type: "credit", amount: 30, reason: "Épargne"}, context("parent-a"));
  const result = await adjustWallet({familyId, childId: "child-a",
    operationId: "debit-1", type: "debit", amount: 10, reason: "Retrait"},
  context("parent-a"));
  assert.equal(result.childPoints, 80);
  assert.equal((await familyRef.collection("children").doc("child-a").get()).data().points, 80);
  assert.equal((await familyRef.collection("children").doc("child-b").get()).data().points, 70);
  const history = await familyRef.collection("history").doc("wallet_debit-1").get();
  assert.equal(history.data().points, 10);
  assert.equal(history.data().walletOperationId, "debit-1");
});

test("annulation simultanée rembourse une seule fois et garde l’audit", async () => {
  const {familyId, familyRef} = await seed("reverse");
  await adjustWallet({familyId, childId: "child-a", operationId: "credit-1",
    type: "credit", amount: 25, reason: "Épargne"}, context("parent-a"));
  const request = {familyId, childId: "child-a", operationId: "credit-1"};
  const results = await Promise.all([
    reverseWalletOperation(request, context("parent-a")),
    reverseWalletOperation(request, context("parent-a")),
  ]);
  assert.equal(results.filter((result) => result.idempotent).length, 1);
  assert.equal((await familyRef.collection("children").doc("child-a").get()).data().points, 100);
  assert.equal((await familyRef.collection("wallets").doc("child-a").get()).data().balance, 0);
  const original = await familyRef.collection("wallets").doc("child-a")
    .collection("operations").doc("credit-1").get();
  assert.equal(original.data().status, "reversed");
  assert.equal(original.data().reversedBy, "parent-a");
  assert.equal(original.data().reversalTransactionId, "reversal_credit-1");
  assert.equal((await familyRef.collection("history")
    .doc("reversal_credit-1").get()).exists, true);
});

test("retry réseau reste idempotent", async () => {
  const {familyId, familyRef} = await seed("retry");
  await adjustWallet({familyId, childId: "child-a", operationId: "credit-1",
    type: "credit", amount: 15, reason: "Épargne"}, context("parent-a"));
  const request = {familyId, childId: "child-a", operationId: "credit-1"};
  await reverseWalletOperation(request, context("parent-a"));
  assert.equal((await reverseWalletOperation(
    request, context("parent-a"))).idempotent, true);
  assert.equal((await familyRef.collection("children").doc("child-a").get()).data().points, 100);
});

test("enfant, membre inactif et autre famille sont refusés", async () => {
  const {familyId} = await seed("roles");
  await adjustWallet({familyId, childId: "child-a", operationId: "credit-1",
    type: "credit", amount: 10, reason: "Épargne"}, context("parent-a"));
  const request = {familyId, childId: "child-a", operationId: "credit-1"};
  for (const uid of ["child-user", "inactive-a", "outsider-a"]) {
    await assert.rejects(
      reverseWalletOperation(request, context(uid)),
      (error) => error.code === "permission-denied"
    );
  }
});

test("opération inexistante ou malformée est refusée", async () => {
  const {familyId, familyRef} = await seed("invalid");
  await assert.rejects(
    reverseWalletOperation({familyId, childId: "child-a",
      operationId: "missing"}, context("parent-a")),
    (error) => error.code === "not-found"
  );
  await familyRef.collection("wallets").doc("child-a").set({
    childId: "child-a", balance: 20,
  });
  await familyRef.collection("wallets").doc("child-a")
    .collection("operations").doc("bad").set({
      childId: "child-a", type: "debit", amount: 0,
    });
  await assert.rejects(
    reverseWalletOperation({familyId, childId: "child-a",
      operationId: "bad"}, context("parent-a")),
    (error) => error.code === "failed-precondition"
  );
});
