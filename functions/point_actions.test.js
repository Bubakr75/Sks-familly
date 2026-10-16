"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {createPointActionFunctions} = require("./point_actions");

function completionFixture(punishment, role = "parent") {
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  let writes = 0;
  const saved = {...punishment};
  const snapshot = (data) => ({exists: true, id: "lines", data: () => data});
  const punishmentRef = {get: async () => snapshot(saved)};
  const familyRef = {get: async () => snapshot({ownerUid: "owner"}),
    collection: (name) => ({doc: () => name === "punishments" ? punishmentRef :
      {get: async () => snapshot({uid: "actor", active: true, role})}})};
  const db = {collection: () => ({doc: () => familyRef}),
    runTransaction: async (fn) => fn({get: () => punishmentRef.get(),
      update: (_, patch) => {writes++; Object.assign(saved, patch);}})};
  const api = createPointActionFunctions({db,
    functions: {https: {HttpsError, onCall: (fn) => fn}},
    admin: {firestore: {FieldValue: {serverTimestamp: () => "server-time"}}}});
  return {saved, writes: () => writes, complete: () => api.completePenaltyLines(
    {familyId: "family", punishmentId: "lines"}, {auth: {uid: "actor"}})};
}

test("valide les lignes manuelles, conserve leur texte et rend le double appel neutre", async () => {
  const f = completionFixture({childId: "child", text: "Ma consigne", totalLines: 15,
    completedLines: 3, photoUrls: ["photo"]});
  await f.complete();
  assert.equal(f.saved.completedLines, 15);
  assert.equal(f.saved.penaltyLinesStatus, "completed");
  assert.equal(f.saved.penaltyLinesCompletedBy, "actor");
  assert.equal(f.saved.pendingValidation, false);
  assert.equal(f.saved.text, "Ma consigne");
  assert.deepEqual(f.saved.photoUrls, ["photo"]);
  await f.complete();
  assert.equal(f.writes(), 1);
});

test("la validation liée reste compatible et un enfant ne peut pas valider", async () => {
  const punishment = {penaltyHistoryId: "history", hasPenaltyLines: true,
    penaltyLinesCount: 20, totalLines: 20};
  const f = completionFixture(punishment);
  await f.complete();
  assert.equal(f.saved.completedLines, 20);
  const child = completionFixture(punishment, "child");
  await assert.rejects(child.complete(), (e) => e.code === "permission-denied");
  assert.equal(child.writes(), 0);
});

test("une obligation sans lignes ne peut pas être validée", async () => {
  const f = completionFixture({totalLines: 0});
  await assert.rejects(f.complete(), (e) => e.code === "failed-precondition");
  assert.equal(f.writes(), 0);
});
const {
  normalizePointAction,
  normalizeHistoryEvent,
  resolveActor,
  fingerprint,
  buildPointHistory,
  buildPenaltyLines,
  validatePhotoMetadata,
} = require("./point_actions");

function payload(overrides = {}) {
  return {
    familyId: "family-a",
    actionId: "action-a",
    childId: "child-a",
    amount: 5,
    reason: "Rangement",
    category: "Pénalité",
    isBonus: false,
    ...overrides,
  };
}

test("normalise une action avec ou sans photo isolée", () => {
  assert.equal(normalizePointAction(payload()).photoStoragePath, null);
  const path = "families/family-a/actions/action-a/proof.webp";
  assert.equal(
    normalizePointAction(payload({photoStoragePath: path})).photoStoragePath,
    path
  );
  assert.throws(
    () => normalizePointAction(payload({
      photoStoragePath: "families/family-b/actions/action-a/proof.jpg",
    })),
    /INVALID_PHOTO_PATH/
  );
});

test("normalise des lignes uniquement pour une pénalité", () => {
  const action = normalizePointAction(payload({
    penaltyLinesCount: 25,
    penaltyLinesInstruction: "Je respecte les règles.",
  }));
  assert.equal(action.penaltyLinesCount, 25);
  assert.equal(action.penaltyLinesInstruction, "Je respecte les règles.");
  assert.throws(
    () => normalizePointAction(payload({penaltyLinesCount: 0})),
    /INVALID_PENALTY_LINES_COUNT/
  );
  assert.throws(
    () => normalizePointAction(payload({penaltyLinesCount: -1})),
    /INVALID_PENALTY_LINES_COUNT/
  );
  assert.throws(
    () => normalizePointAction(payload({
      isBonus: true,
      penaltyLinesCount: 10,
    })),
    /INVALID_PENALTY_LINES_COUNT/
  );
});

test("construit une obligation en attente liée à la pénalité", () => {
  const action = normalizePointAction(payload({
    penaltyLinesCount: 12,
    penaltyLinesInstruction: "Texte",
  }));
  const punishment = buildPenaltyLines({
    action,
    actor: {actorUid: "parent-a"},
    createdAt: "server-time",
    serverDate: "2026-08-06T10:00:00.000Z",
  });
  assert.equal(punishment.penaltyHistoryId, "action-a");
  assert.equal(punishment.penaltyLinesStatus, "pending");
  assert.equal(punishment.penaltyLinesCompletedBy, null);
});

test("construit une pénalité modifiable même sans lignes", () => {
  const action = normalizePointAction(payload());
  const punishment = buildPenaltyLines({
    action,
    actor: {actorUid: "parent-a"},
    createdAt: "server-time",
    serverDate: "2026-08-06T10:00:00.000Z",
  });
  assert.equal(punishment.hasPenaltyLines, false);
  assert.equal(punishment.penaltyLinesCount, 0);
  assert.equal(punishment.penaltyLinesStatus, "completed");
});

test("valide le type et la taille du fichier Storage", () => {
  const action = normalizePointAction(payload({
    photoStoragePath: "families/family-a/actions/action-a/proof.jpg",
  }));
  assert.doesNotThrow(() => validatePhotoMetadata(action, {
    contentType: "image/jpeg",
    size: "2048",
  }));
  assert.throws(
    () => validatePhotoMetadata(action, {
      contentType: "application/pdf",
      size: "2048",
    }),
    /INVALID_PHOTO_METADATA/
  );
  assert.throws(
    () => validatePhotoMetadata(action, {
      contentType: "image/jpeg",
      size: String(5 * 1024 * 1024 + 1),
    }),
    /INVALID_PHOTO_METADATA/
  );
});

test("l'auteur vient exclusivement du membre actif", () => {
  const actor = resolveActor({
    uid: "uid-maman",
    family: {ownerUid: "uid-owner"},
    member: {
      uid: "uid-maman",
      active: true,
      role: "parent",
      displayName: "Maman",
    },
  });
  assert.deepEqual(actor, {
    actorUid: "uid-maman",
    actorDisplayName: "Maman",
    actorRole: "parent",
  });
  assert.equal(resolveActor({
    uid: "uid-child",
    family: {},
    member: {uid: "uid-child", active: true, role: "child"},
  }), null);
  assert.equal(resolveActor({
    uid: "uid-parent",
    family: {},
    member: {uid: "uid-parent", active: false, role: "parent"},
  }), null);
  assert.equal(resolveActor({
    uid: "uid-manager",
    family: {ownerUid: "uid-owner"},
    member: {uid: "uid-manager", active: true, role: "manager"},
  }), null);
  assert.deepEqual(resolveActor({
    uid: "uid-manager",
    family: {ownerUid: "uid-owner"},
    member: {
      uid: "uid-manager",
      active: true,
      role: "manager",
      displayName: "Gestionnaire",
    },
    managerDurableVerified: true,
  }), {
    actorUid: "uid-manager",
    actorDisplayName: "Gestionnaire",
    actorRole: "manager",
  });
});

test("un événement historique ignore les champs d'auteur du client", () => {
  const event = normalizeHistoryEvent({
    familyId: "family-a",
    eventId: "event-a",
    childId: "child-a",
    points: 10,
    reason: "Événement",
    category: "immunité",
    isBonus: true,
    actorUid: "forged",
    actorRole: "owner",
  });
  assert.equal("actorUid" in event, false);
  assert.equal("actorRole" in event, false);
});

test("les champs auteur forgés n'entrent pas dans l'action normalisée", () => {
  const action = normalizePointAction(payload({
    actorUid: "victime",
    actorDisplayName: "Faux parent",
    actorRole: "owner",
    createdAt: "1900-01-01",
  }));
  assert.equal("actorUid" in action, false);
  assert.equal("actorDisplayName" in action, false);
  assert.equal("actorRole" in action, false);
  assert.equal("createdAt" in action, false);
});

test("l'historique prend l'auteur réel et l'horodatage serveur", () => {
  const action = normalizePointAction(payload({
    actorUid: "victime",
    actorDisplayName: "Faux parent",
  }));
  const serverTimestamp = {serverTimestamp: true};
  const history = buildPointHistory({
    action,
    actor: {
      actorUid: "uid-auth",
      actorDisplayName: "Maman",
      actorRole: "parent",
    },
    actualAmount: 5,
    createdAt: serverTimestamp,
    serverDate: "2026-07-30T12:00:00.000Z",
  });
  assert.equal(history.actorUid, "uid-auth");
  assert.equal(history.actorDisplayName, "Maman");
  assert.equal(history.actorRole, "parent");
  assert.equal(history.createdAt, serverTimestamp);
  assert.equal(history.proofPhotoPath, null);
});

test("l'idempotence dépend du contenu et de l'UID authentifié", () => {
  const action = normalizePointAction(payload());
  assert.equal(fingerprint(action, "uid-a"), fingerprint(action, "uid-a"));
  assert.notEqual(fingerprint(action, "uid-a"), fingerprint(action, "uid-b"));
});
