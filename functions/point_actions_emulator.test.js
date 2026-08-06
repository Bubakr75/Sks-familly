"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const admin = require("firebase-admin");

const {
  createPointActionFunctions,
} = require("./point_actions");

const PROJECT_ID = "demo-sks-family";
let app;
let db;
let recordPointAction;
let completePenaltyLines;
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

function parentContext() {
  return {
    auth: {
      uid: "parent-a",
      token: {
        email_verified: true,
        firebase: {sign_in_provider: "password"},
      },
    },
  };
}

function childContext() {
  return {auth: {uid: "child-a", token: {}}};
}

async function seedFamily(label, points = 40) {
  sequence += 1;
  const familyId = `point-actions-${label}-${process.pid}-${sequence}`;
  const familyRef = db.collection("families").doc(familyId);
  await familyRef.set({ownerUid: "owner-a", schemaVersion: 2});
  await familyRef.collection("members").doc("parent-a").set({
    uid: "parent-a",
    role: "parent",
    active: true,
    displayName: "Parent test",
  });
  await familyRef.collection("children").doc("child-a").set({
    id: "child-a",
    name: "Enfant test",
    points,
  });
  return {familyId, familyRef};
}

async function uploadProof(familyId, actionId) {
  const path = `families/${familyId}/actions/${actionId}/proof.jpg`;
  await admin.storage(app).bucket().file(path).save(
    Buffer.from([0xff, 0xd8, 0xff, 0xd9]),
    {metadata: {contentType: "image/jpeg"}}
  );
  return path;
}

test.before(() => {
  assert.equal(PROJECT_ID, "demo-sks-family");
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "Le test refuse de contacter un Firestore réel."
  );
  assert.ok(
    process.env.FIREBASE_STORAGE_EMULATOR_HOST,
    "Le test refuse de contacter un Storage réel."
  );
  app = admin.initializeApp(
    {
      projectId: PROJECT_ID,
      storageBucket: `${PROJECT_ID}.appspot.com`,
    }
  );
  db = admin.firestore(app);
  const pointActionFunctions = createPointActionFunctions({
    functions: fakeFunctions,
    admin,
    db,
  });
  recordPointAction = pointActionFunctions.recordPointAction;
  completePenaltyLines = pointActionFunctions.completePenaltyLines;
});

test.after(async () => {
  if (app) await app.delete();
});

for (const isBonus of [true, false]) {
  for (const custom of [true, false]) {
    for (const withPhoto of [true, false]) {
      test(
        `${isBonus ? "bonus" : "pénalité"} ` +
        `${custom ? "personnalisé" : "prédéfini"} ` +
        `${withPhoto ? "avec" : "sans"} photo`,
        async () => {
          const seeded = await seedFamily(
            `${isBonus}-${custom}-${withPhoto}`
          );
          const actionId = `action-${sequence}`;
          const photoStoragePath = withPhoto
            ? await uploadProof(seeded.familyId, actionId)
            : null;
          const result = await recordPointAction(
            {
              familyId: seeded.familyId,
              actionId,
              childId: "child-a",
              amount: 5,
              reason: custom
                ? "Motif personnalisé"
                : "Motif prédéfini",
              category: isBonus ? "Bonus" : "Pénalité",
              isBonus,
              photoStoragePath,
            },
            parentContext()
          );
          assert.equal(result.newBalance, isBonus ? 45 : 35);
          assert.equal(result.history.points, 5);
          assert.equal(result.history.isBonus, isBonus);
          assert.equal(result.history.proofPhotoPath, photoStoragePath);
          const history = await seeded.familyRef
            .collection("history")
            .doc(actionId)
            .get();
          assert.equal(history.exists, true);
        }
      );
    }
  }
}

test("double validation est idempotente côté serveur", async () => {
  const seeded = await seedFamily("double");
  const payload = {
    familyId: seeded.familyId,
    actionId: "same-action",
    childId: "child-a",
    amount: 7,
    reason: "Double appui",
    category: "Bonus",
    isBonus: true,
  };
  const first = await recordPointAction(payload, parentContext());
  const second = await recordPointAction(payload, parentContext());
  assert.equal(first.idempotent, false);
  assert.equal(second.idempotent, true);
  assert.equal(second.newBalance, 47);
  assert.equal(
    (await seeded.familyRef
      .collection("history")
      .where("reason", "==", "Double appui")
      .get()).size,
    1
  );
});

test("lignes créées puis validées uniquement par un parent", async () => {
  const seeded = await seedFamily("penalty-lines");
  const result = await recordPointAction(
    {
      familyId: seeded.familyId,
      actionId: "penalty-lines-action",
      childId: "child-a",
      amount: 5,
      reason: "Manque de respect",
      category: "Pénalité",
      isBonus: false,
      penaltyLinesCount: 30,
      penaltyLinesInstruction: "Je parle calmement.",
    },
    parentContext()
  );
  assert.equal(result.punishment.penaltyLinesStatus, "pending");
  const punishmentRef = seeded.familyRef
    .collection("punishments")
    .doc("penalty-lines-action");
  assert.equal((await punishmentRef.get()).data().penaltyLinesCount, 30);

  await assert.rejects(
    completePenaltyLines(
      {familyId: seeded.familyId, punishmentId: "penalty-lines-action"},
      childContext()
    ),
    (error) => error.code === "permission-denied"
  );
  await completePenaltyLines(
    {familyId: seeded.familyId, punishmentId: "penalty-lines-action"},
    parentContext()
  );
  const completed = (await punishmentRef.get()).data();
  assert.equal(completed.penaltyLinesStatus, "completed");
  assert.equal(completed.penaltyLinesCompletedBy, "parent-a");
  assert.equal(completed.completedLines, 30);
});

test("enfant changé avant validation cible uniquement la valeur capturée", async () => {
  const seeded = await seedFamily("captured-child");
  await seeded.familyRef.collection("children").doc("child-b").set({
    id: "child-b",
    name: "Autre enfant",
    points: 20,
  });
  await recordPointAction(
    {
      familyId: seeded.familyId,
      actionId: "captured-action",
      childId: "child-a",
      amount: 6,
      reason: "Valeur capturée",
      category: "Pénalité",
      isBonus: false,
    },
    parentContext()
  );
  const [childA, childB] = await Promise.all([
    seeded.familyRef.collection("children").doc("child-a").get(),
    seeded.familyRef.collection("children").doc("child-b").get(),
  ]);
  assert.equal(childA.data().points, 34);
  assert.equal(childB.data().points, 20);
});

test("appel non authentifié refusé sans écriture", async () => {
  const seeded = await seedFamily("unauthenticated");
  await assert.rejects(
    recordPointAction(
      {
        familyId: seeded.familyId,
        actionId: "forbidden-action",
        childId: "child-a",
        amount: 5,
        reason: "Interdit",
        category: "Bonus",
        isBonus: true,
      },
      {}
    ),
    (error) => error.code === "unauthenticated"
  );
  assert.equal(
    (await seeded.familyRef
      .collection("history")
      .doc("forbidden-action")
      .get()).exists,
    false
  );
});
