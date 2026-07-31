"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizePointAction,
  normalizeHistoryEvent,
  resolveActor,
  fingerprint,
  buildPointHistory,
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
