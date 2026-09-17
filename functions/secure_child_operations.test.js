"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  normalizeSecureOperation,
  memberRole,
  authorizeChildTarget,
  operationFingerprint,
  isMatchingReplay,
  applyTradeTransition,
  buildPurchaseRequest,
  linkedPurchaseIdForRequest,
  createSecureChildOperationFunctions,
} = require("./secure_child_operations");

function tribunalHarness({role = "child", active = true} = {}) {
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const store = new Map([
    ["families/f", {ownerUid: "owner"}],
    ["families/f/members/u", {uid: "u", role, active, childId: "c1"}],
    ["families/f/children/c1", {name: "Test 1"}],
    ["families/f/children/c2", {name: "Test 2"}],
    ["families/f/fcm_tokens/sender", {uid: "u", token: "fake-sender"}],
    ["families/f/fcm_tokens/parent", {uid: "parent", token: "fake-parent"}],
  ]);
  const snapshot = path => ({exists: store.has(path), data: () => store.get(path)});
  const ref = path => ({path, collection: name => ref(path + "/" + name),
    doc: id => ref(path + "/" + id),
    get: async () => ({empty: false, docs: [...store].filter(([key]) => key.startsWith(path + "/"))
      .map(([key, value]) => ({id: key.split("/").pop(), data: () => value}))})});
  const db = {collection: name => ref(name), runTransaction: async fn => {
    const writes = [];
    const result = await fn({get: async r => snapshot(r.path), create: (r, data) => writes.push([r.path, data])});
    for (const [path] of writes) assert.equal(store.has(path), false);
    for (const [path, data] of writes) store.set(path, data);
    return result;
  }};
  const functions = {https: {HttpsError, onCall: fn => fn},
    firestore: {document: () => ({onCreate: fn => fn, onUpdate: fn => fn})}};
  const sent = [];
  const admin = {initializeApp() {}, firestore: Object.assign(() => db,
    {FieldValue: {serverTimestamp: () => "server-time"}}),
    messaging: () => ({sendEachForMulticast: async message => {
      sent.push(message); return {successCount: message.tokens.length,
        responses: message.tokens.map(() => ({success: true}))};
    }})};
  const call = createSecureChildOperationFunctions({functions, admin, db}).performFamilyOperation;
  const payload = {familyId: "f", operationId: "case-1", operation: "tribunal_create",
    senderDeviceId: "sender", tribunal: {title: "Affaire test", description: "Ligne 1\nLigne 2",
      plaintiffId: "c1", accusedId: "c2"}};
  const auth = {auth: {uid: "u", token: {}}};
  return {store, db, functions, admin, sent, call, payload, auth};
}

test("tribunal : enfant enregistre au serveur, notification vers autre mobile, rejeu sans doublon", async () => {
  const h = tribunalHarness();
  const result = await h.call(h.payload, h.auth);
  const saved = h.store.get("families/f/tribunal/case-1");
  assert.equal(saved.title, "Affaire test");
  assert.equal(saved.lastModifiedBy, "sender");
  assert.equal(result.tribunal.status, "filed");
  assert.equal((await h.call(h.payload, h.auth)).idempotent, true);
  assert.equal([...h.store.keys()].filter(key => key.includes("/tribunal/")).length, 1);
  const exports = {};
  require("node:vm").runInNewContext(require("node:fs").readFileSync(
    require("node:path").join(__dirname, "index.js"), "utf8"), {
    exports, console: {log() {}, error() {}},
    require: name => name === "firebase-functions" ? h.functions : name === "firebase-admin" ? h.admin :
      new Proxy({}, {get: () => () => ({})}),
  });
  await exports.onTribunalCreated({data: () => saved}, {params: {familyId: "f", caseId: "case-1"}});
  assert.deepEqual([...h.sent[0].tokens], ["fake-parent"]);
  assert.equal(h.sent[0].data.type, "tribunal_new");
  assert.equal(h.sent[0].data.caseId, result.caseId);
  assert.ok(h.sent[0].notification.title);
});

test("tribunal : refus des dépôts non authentifiés, membres inactifs et usurpations", async () => {
  for (const variant of ["anonymous", "inactive", "other-child", "other-family"]) {
    const h = tribunalHarness({active: variant !== "inactive"});
    if (variant === "other-child") h.payload.tribunal.plaintiffId = "c2";
    if (variant === "other-child") h.payload.tribunal.accusedId = "c1";
    if (variant === "other-family") h.payload.familyId = "other";
    await assert.rejects(h.call(h.payload, variant === "anonymous" ? {} : h.auth));
    assert.equal(h.store.has("families/f/tribunal/case-1"), false);
  }
});

test("tribunal : participant absent, mêmes parties et titre vide refusés", async () => {
  for (const change of [{accusedId: "unknown"}, {accusedId: "c1"}, {title: " "},
    {title: "x".repeat(201)}, {description: "x".repeat(4001)}]) {
    const h = tribunalHarness();
    Object.assign(h.payload.tribunal, change);
    await assert.rejects(h.call(h.payload, h.auth));
    assert.equal(h.store.has("families/f/tribunal/case-1"), false);
  }
});

test("tribunal : parent autorisé, verdict et points imposés par serveur, sender vérifié", async () => {
  const h = tribunalHarness({role: "parent"});
  Object.assign(h.payload.tribunal, {status: "closed", verdict: "guilty", plaintiffPoints: 999,
    votingEnabled: true, votes: [{childId: "c1", vote: "guilty"}]});
  h.payload.senderDeviceId = "parent";
  const {tribunal} = await h.call(h.payload, h.auth);
  assert.equal(tribunal.status, "filed");
  assert.equal(tribunal.verdict, null);
  assert.equal(tribunal.plaintiffPoints, 0);
  assert.equal(tribunal.votingEnabled, false);
  assert.deepEqual(tribunal.votes, []);
  assert.equal(tribunal.lastModifiedBy, "u");
  h.payload.tribunal.title = "Autre affaire";
  await assert.rejects(h.call(h.payload, h.auth), {code: "already-exists"});
});

test("normalise uniquement une opération et des identifiants stricts", () => {
  assert.equal(normalizeSecureOperation({
    familyId: " family-1 ", operationId: "op-1",
    operation: "screen_start", childId: "child-1", minutes: 30,
  }).familyId, "family-1");
  assert.throws(() => normalizeSecureOperation({
    familyId: "family/other", operationId: "op",
    operation: "screen_start", childId: "child", minutes: 30,
  }), /INVALID_FAMILY_ID/);
  assert.throws(() => normalizeSecureOperation({
    familyId: "family", operationId: "op",
    operation: "screen_start", childId: "child", minutes: 1000,
  }), /INVALID_MINUTES/);
});

test("l'autorité vient du membre actif et du vrai owner", () => {
  assert.equal(memberRole({
    uid: "child-uid", family: {ownerUid: "owner"},
    member: {uid: "child-uid", role: "child", childId: "c1", active: true},
  }), "child");
  assert.equal(memberRole({
    uid: "fake", family: {ownerUid: "owner"},
    member: {uid: "fake", role: "owner", active: true},
  }), null);
  assert.equal(authorizeChildTarget({
    role: "child", member: {childId: "c1"}, childId: "c2",
  }), false);
  assert.equal(memberRole({
    uid: "manager", family: {ownerUid: "owner"},
    member: {uid: "manager", role: "manager", active: true},
    authToken: {email_verified: true, firebase: {sign_in_provider: "password"}},
  }), "parent");
  assert.equal(memberRole({
    uid: "manager", family: {ownerUid: "owner"},
    member: {uid: "manager", role: "manager", active: true},
    authToken: {firebase: {sign_in_provider: "anonymous"}},
  }), null);
});

test("les paramètres de vente et de validation sont strictement bornés", () => {
  const sale = normalizeSecureOperation({familyId: "f", operationId: "o",
    operation: "sale_set", percent: 50, durationHours: 24, label: "Weekend"});
  assert.equal(sale.percent, 50);
  assert.throws(() => normalizeSecureOperation({familyId: "f", operationId: "o",
    operation: "sale_set", percent: 100, durationHours: 24}), /INVALID_PERCENT/);
  assert.equal(normalizeSecureOperation({familyId: "f", operationId: "o",
    operation: "purchase_reject", requestId: "r", reason: "Non"}).requestId, "r");
});

test("l'idempotence accepte seulement un rejeu identique", () => {
  const op = {familyId: "f", operationId: "o", operation: "screen_stop", childId: "c"};
  const fingerprint = operationFingerprint(op, "uid");
  assert.equal(isMatchingReplay({fingerprint}, fingerprint), true);
  assert.notEqual(operationFingerprint({...op, childId: "other"}, "uid"), fingerprint);
});

test("les transitions d'échange sont strictes", () => {
  assert.equal(applyTradeTransition("pending", "trade_accept"), "accepted");
  assert.equal(applyTradeTransition("accepted", "trade_service_done"), "service_done");
  assert.throws(() => applyTradeTransition("rejected", "trade_accept"), /INVALID_TRADE_TRANSITION/);
});

test("les lignes et descriptions d'échange sont bornées", () => {
  const base = {
    familyId: "f", operationId: "o", operation: "trade_create",
    childId: "c1", toChildId: "c2", immunityLines: 1,
    description: "Service",
  };
  assert.equal(normalizeSecureOperation(base).immunityLines, 1);
  assert.throws(
    () => normalizeSecureOperation({...base, immunityLines: 101}),
    /INVALID_IMMUNITY_LINES/
  );
  assert.throws(
    () => normalizeSecureOperation({...base, description: "x".repeat(301)}),
    /INVALID_DESCRIPTION/
  );
});

test("un achat serveur cree une demande de validation pour la cloche", () => {
  const request = buildPurchaseRequest({
    operationId: "purch-1",
    childId: "child-1",
    childName: "Enfant",
    reward: {id: "reward-1", title: "30 min ecran", icon: "game"},
    cost: 25,
    actorUid: "uid-enfant",
    now: "2026-08-14T12:00:00.000Z",
  });
  assert.equal(request.id, "purch-1");
  assert.equal(request.type, "boutique");
  assert.equal(request.status, "pending");
  assert.equal(request.extra.purchaseId, "purch-1");
  assert.equal(request.extra.rewardTitle, "30 min ecran");
  assert.deepEqual(request.readBy, []);
});

test("une ancienne demande retrouve son identifiant d'achat lié", () => {
  assert.equal(linkedPurchaseIdForRequest({
    extra: {purchaseId: "purchase-original"},
  }, "request-restored"), "purchase-original");
  assert.equal(linkedPurchaseIdForRequest({extra: {}}, "same-id"), "same-id");
  assert.equal(linkedPurchaseIdForRequest({
    extra: {purchaseId: "invalid/id"},
  }, "safe-id"), "safe-id");
});
