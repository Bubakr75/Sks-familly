"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {createPointActionFunctions} = require("./point_actions");

test("le changement de barème refuse les anciennes attributions sans modifier le solde", async () => {
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const store = new Map([
    ["families/f", {ownerUid: "owner", pointsScaleVersion: 2}],
    ["families/f/members/u", {uid: "u", role: "parent", active: true}],
    ["families/f/children/c", {points: 100}],
  ]);
  const ref = path => ({path, collection: name => ref(`${path}/${name}`), doc: id => ref(`${path}/${id}`)});
  const db = {collection: name => ref(name), runTransaction: async callback => callback({
    get: async reference => ({exists: store.has(reference.path), data: () => store.get(reference.path)}),
    update: (reference, patch) => store.set(reference.path, {...store.get(reference.path), ...patch}),
    create: (reference, data) => store.set(reference.path, data),
  })};
  const api = createPointActionFunctions({db,
    functions: {https: {HttpsError, onCall: handler => handler}},
    admin: {firestore: {FieldValue: {serverTimestamp: () => "now"}}}});
  const action = {familyId: "f", actionId: "a", childId: "c", amount: 200, reason: "Aide", category: "Bonus", isBonus: true};
  await assert.rejects(api.recordPointAction(action, {auth: {uid: "u"}}), {code: "failed-precondition"});
  assert.equal(store.get("families/f/children/c").points, 100);
  const result = await api.recordPointAction({...action, amount: 1, pointsScaleVersion: 2}, {auth: {uid: "u"}});
  assert.equal(result.newBalance, 101);
  assert.equal(result.history.pointsScaleVersion, 2);
  store.set('families/f/children/c', {points: 0});
  const sanction = await api.recordPointAction({...action, actionId: 'sanction-zero', isBonus: false, amount: 0, pointsScaleVersion: 2, penaltyLinesCount: 1, penaltyLinesInstruction: 'Ranger les jouets', sanctionType: 'chore', sanctionLabel: 'Rangement'}, {auth: {uid: 'u'}});
  assert.equal(sanction.newBalance, 0);
  assert.equal(sanction.history.points, 0);
  assert.equal(sanction.punishment.penaltyLinesStatus, 'pending');
});

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

test("corvée et sanction personnalisée conservent leur type et leur consigne", async () => {
  for (const sanctionType of ["chore", "custom"]) {
    const action = normalizePointAction(payload({
      amount: 1, sanctionType, sanctionLabel: "Rangement",
      penaltyLinesCount: 1, penaltyLinesInstruction: "Ranger les jouets",
    }));
    const punishment = buildPenaltyLines({action, actor: {actorUid: "parent-a"}, createdAt: "now", serverDate: "now"});
    assert.equal(punishment.sanctionType, sanctionType);
    assert.equal(punishment.sanctionLabel, "Rangement");
    assert.equal(punishment.text, "Ranger les jouets");
    assert.equal(punishment.penaltyLinesStatus, "pending");
    const fixture = completionFixture(punishment);
    await fixture.complete();
    assert.equal(fixture.saved.penaltyLinesStatus, "completed");
  }
});

test("sanctions : type inconnu, consigne vide et faux nombre de corvées refusés", () => {
  const chore = {sanctionType: "chore", sanctionLabel: "Corvée", penaltyLinesCount: 1, penaltyLinesInstruction: "Ranger"};
  for (const invalid of [{sanctionType: "unknown"}, {penaltyLinesInstruction: ""}, {penaltyLinesCount: 20}, {sanctionLabel: ""}, {isBonus: true}]) {
    assert.throws(() => normalizePointAction(payload({...chore, ...invalid})), /INVALID_/);
  }
});

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

 test('une sanction sans retrait accepte zéro, un bonus ou retrait vide le refuse', () => {
 const sanction = {...payload(), isBonus: false, amount: 0, penaltyLinesCount: 1, penaltyLinesInstruction: 'Ranger sa chambre', sanctionType: 'chore', sanctionLabel: 'Rangement'};
 assert.equal(normalizePointAction(sanction).amount, 0);
 assert.throws(() => normalizePointAction({...sanction, penaltyLinesCount: null}), /INVALID/);
 assert.throws(() => normalizePointAction({...payload(), amount: 0}), /INVALID_AMOUNT/);
 });

for (const type of ['essay', 'repair', 'yellow_card', 'red_card']) {
 test('catégorie '+type+' validée et conservée sans retrait', () => {
 const a=normalizePointAction({...payload(), amount:0, isBonus:false, penaltyLinesCount:type==='essay'?12:1, penaltyLinesInstruction:'Consigne du parent', sanctionType:type, sanctionLabel:type});
 assert.equal(a.sanctionType,type); assert.equal(a.amount,0);
 const p=buildPenaltyLines({action:a,actor:{actorUid:'parent'},createdAt:'now',serverDate:'now'});
 assert.equal(p.penaltyLinesStatus,'pending');assert.equal(p.totalLines,type==='essay'?12:1);
 });
}
test('rédaction vide et carton avec faux nombre de lignes refusés', () => {
 assert.throws(()=>normalizePointAction({...payload(),isBonus:false,amount:0,penaltyLinesCount:10,penaltyLinesInstruction:'',sanctionType:'essay',sanctionLabel:'Réflexion'}),/INVALID/);
 assert.throws(()=>normalizePointAction({...payload(),isBonus:false,amount:0,penaltyLinesCount:10,penaltyLinesInstruction:'Chambre',sanctionType:'red_card',sanctionLabel:'Carton rouge'}),/INVALID/);
});
