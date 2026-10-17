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
  screenTimeOfferCost,
} = require("./secure_child_operations");

test("les forfaits écran sont fixés au serveur : 3 points / 30 min, 5 points / 60 min", () => {
  assert.equal(screenTimeOfferCost(30), 3);
  assert.equal(screenTimeOfferCost(60), 5);
  for (const minutes of [0, 1, 15, 31, 120, "30"]) {
    assert.throws(() => screenTimeOfferCost(minutes), /INVALID_SCREEN_OFFER/);
  }
});

test("achat direct : solde exact, débit et crédit atomiques, rejeu sans doublon", async () => {
  for (const [minutes, points] of [[30, 3], [60, 5]]) {
    const h = purchaseHarness({points, pointsScaleVersion: 2});
    const data = {...h.payload, operation: "screen_buy", pointsScaleVersion: 2, minutes};
    const result = await h.call(data, h.auth);
    assert.equal(result.points, 0);
    assert.equal(result.account.balanceMinutes, minutes);
    const replay = await h.call(data, h.auth);
    assert.equal(replay.idempotent, true);
    assert.equal(h.store.get("families/f/children/c1").points, 0);
    assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes, minutes);
    assert.equal(h.store.get("families/f/history/purchase-1").points, points);
  }
});

test("achat direct : deux achats concurrents ne dépassent pas le solde", async () => {
  const h = purchaseHarness({points: 5, pointsScaleVersion: 2});
  const data = {...h.payload, operation: "screen_buy", pointsScaleVersion: 2, minutes: 30};
  const results = await Promise.allSettled([
    h.call(data, h.auth),
    h.call({...data, operationId: "second-purchase"}, h.auth),
  ]);
  assert.equal(results.filter(value => value.status === "fulfilled").length, 1);
  assert.equal(h.store.get("families/f/children/c1").points, 2);
  assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 30);
});

test("achat direct : fonds insuffisants, usurpation, forfait invalide et sanction bloquante refusés", async () => {
  const h = purchaseHarness({points: 2, pointsScaleVersion: 2});
  const data = {...h.payload, operation: "screen_buy", pointsScaleVersion: 2, minutes: 30};
  await assert.rejects(h.call(data, h.auth), {code: "failed-precondition"});
  await assert.rejects(h.call({...data, childId: "c2"}, h.auth), {code: "permission-denied"});
  await assert.rejects(h.call({...data, minutes: 15}, h.auth));
  assert.equal(h.store.has("families/f/screen_time_accounts/c1"), false);
  h.store.set("families/f/children/c1", {name: "Test", points: 5});
  h.store.set("families/f/punishments/task", {childId: "c1", penaltyHistoryId: "task", hasPenaltyLines: true, penaltyLinesCount: 1, penaltyLinesStatus: "pending", sanctionType: "chore"});
  await assert.rejects(h.call(data, h.auth), {code: "failed-precondition"});
  assert.equal(h.store.get("families/f/children/c1").points, 5);
  h.store.get("families/f/punishments/task").penaltyLinesStatus = "completed";
  assert.equal((await h.call(data, h.auth)).points, 2);
});

function tribunalHarness({role = "child", active = true, pointsScaleVersion} = {}) {
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const store = new Map([
    ["families/f", {ownerUid: "owner", ...(pointsScaleVersion ? {pointsScaleVersion} : {})}],
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

function purchaseHarness({role = "child", active = true, points = 100, reward, pointsScaleVersion} = {}) {
  class HttpsError extends Error {
    constructor(code, message) { super(message); this.code = code; }
  }
  const store = new Map([
    ["families/f", {ownerUid: "owner", ...(pointsScaleVersion ? {pointsScaleVersion} : {})}],
    ["families/f/members/u", {uid: "u", role, active, childId: "c1"}],
    ["families/f/members/parent", {uid: "parent", role: "parent", active: true}],
    ["families/f/children/c1", {name: "Test", points}],
    ["families/f/children/c2", {name: "Other", points: 100}],
    ["families/f/rewards/r", reward || {title: "30 min ecran", icon: "game", cost: 20}],
    ["families/f/settings/shop", {percent: 50,
      endAt: new Date(Date.now() + 60_000).toISOString()}],
  ]);
  const snapshot = path => ({exists: store.has(path), data: () => store.get(path)});
  const ref = path => ({path, id: path.split("/").pop(),
    collection: name => ref(path + "/" + name), doc: id => ref(path + "/" + id),
    where: (field, operator, value) => ({path, query: {field, operator, value}})});
  let tail = Promise.resolve();
  const db = {collection: name => ref(name), runTransaction: fn => {
    const run = tail.then(async () => {
      const writes = [];
      const result = await fn({
        get: async r => r.query ? {docs: [...store]
          .filter(([key, value]) => key.startsWith(r.path + "/") && value[r.query.field] === r.query.value)
          .map(([key, value]) => ({id: key.split("/").pop(), data: () => value}))} : snapshot(r.path),
        create: (r, data) => writes.push({type: "create", path: r.path, data}),
        update: (r, data) => writes.push({type: "update", path: r.path, data}),
        set: (r, data) => writes.push({type: "set", path: r.path, data}),
        delete: r => writes.push({type: "delete", path: r.path}),
      });
      for (const write of writes) {
        if (write.type === "create" && store.has(write.path)) {
          const error = new Error("already exists"); error.code = "already-exists"; throw error;
        }
        if (write.type === "update" && !store.has(write.path)) throw new Error("missing update");
      }
      for (const write of writes) {
        if (write.type === "delete") store.delete(write.path);
        else if (write.type === "update" || write.type === "set") {
          store.set(write.path, {...(store.get(write.path) || {}), ...write.data});
        } else store.set(write.path, write.data);
      }
      return result;
    });
    tail = run.catch(() => {});
    return run;
  }};
  const functions = {https: {HttpsError, onCall: fn => fn},
    firestore: {document: () => ({onCreate: fn => fn, onUpdate: fn => fn})}};
  const admin = {initializeApp() {}, firestore: Object.assign(() => db,
    {FieldValue: {serverTimestamp: () => "server-time"}}), messaging: () => ({})};
  const call = createSecureChildOperationFunctions({functions, admin, db}).performFamilyOperation;
  const payload = {familyId: "f", operationId: "purchase-1", operation: "purchase_reward",
    childId: "c1", rewardId: "r", clientPrice: 0, minutes: 999};
  return {store, call, payload, auth: {auth: {uid: "u", token: {}}},
    parentAuth: {auth: {uid: "parent", token: {}}}};
}

test("après conversion, l’ancien client est refusé et le nouveau garde les achats fonctionnels", async () => {
  const h = purchaseHarness({points: 30, pointsScaleVersion: 2});
  await assert.rejects(h.call(h.payload, h.auth), {code: "failed-precondition"});
  assert.equal(h.store.get("families/f/children/c1").points, 30);
  const result = await h.call({...h.payload, pointsScaleVersion: 2}, h.auth);
  assert.equal(result.points, 20);
});

test("un forfait bon marché est refusé avant la conversion des anciens soldes", async () => {
  const h = purchaseHarness({points: 300});
  await assert.rejects(h.call({...h.payload, operation: "screen_buy", minutes: 30, pointsScaleVersion: 2}, h.auth), {code: "failed-precondition"});
  assert.equal(h.store.get("families/f/children/c1").points, 300);
});

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

test("achat temps serveur : débit et documents atomiques, solde minutes inchangé", async () => {
  const h = purchaseHarness();
  const result = await h.call(h.payload, h.auth);
  assert.equal(result.points, 90);
  assert.equal(result.purchase.cost, 10);
  assert.equal(result.purchase.screenTimeMinutes, 30);
  assert.equal(result.purchase.settlementVersion, 2);
  assert.ok(result.purchase.pointsDebitedAt);
  assert.equal(h.store.get("families/f/children/c1").points, 90);
  assert.equal(h.store.has("families/f/screen_time_accounts/c1"), false);
  assert.equal(h.store.get("families/f/requests/purchase-1").extra.screenTimeMinutes, 30);
  assert.equal(h.store.get("families/f/history/purchase-1_purchase").points, 10);
  assert.equal(h.store.get("families/f/history/purchase-1_purchase").id,
    "purchase-1_purchase");
});

test("achat refuse le solde insuffisant, l'enfant cible un autre enfant et un membre inactif", async () => {
  const insufficient = purchaseHarness({points: 5});
  await assert.rejects(insufficient.call(insufficient.payload, insufficient.auth));
  assert.equal(insufficient.store.has("families/f/purchases/purchase-1"), false);
  const otherChild = purchaseHarness();
  otherChild.payload.childId = "c2";
  await assert.rejects(otherChild.call(otherChild.payload, otherChild.auth));
  const inactive = purchaseHarness({active: false});
  await assert.rejects(inactive.call(inactive.payload, inactive.auth));
});

test("prix/minutes falsifiés ignorés et rejeu du même operationId sans second débit", async () => {
  const h = purchaseHarness();
  const first = await h.call(h.payload, h.auth);
  const replay = await h.call({...h.payload, clientPrice: 1, minutes: 1}, h.auth);
  assert.equal(first.points, 90);
  assert.equal(replay.idempotent, true);
  assert.equal(h.store.get("families/f/children/c1").points, 90);
  assert.equal([...h.store.keys()].filter(key => key.includes("/purchases/")).length, 1);
  await assert.rejects(h.call({...h.payload, rewardId: "other"}, h.auth));
});

test("approbation créditant une fois, ID de demande différent et rejeu sûr", async () => {
  const h = purchaseHarness();
  await h.call(h.payload, h.auth);
  const request = h.store.get("families/f/requests/purchase-1");
  request.id = "restored-request";
  request.extra.purchaseId = "purchase-1";
  h.store.delete("families/f/requests/purchase-1");
  h.store.set("families/f/requests/restored-request", request);
  const approve = {familyId: "f", operation: "purchase_approve",
    operationId: "review-1", requestId: "restored-request"};
  const first = await h.call(approve, h.parentAuth);
  assert.equal(first.status, "approved");
  assert.equal(first.minutes, 30);
  assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 30);
  assert.equal(h.store.has("families/f/requests/restored-request"), false);
  assert.equal((await h.call(approve, h.parentAuth)).idempotent, true);
  assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 30);
  await assert.rejects(h.call({...approve, operationId: "review-2"}, h.parentAuth));
});

test("deux responsables concurrents ne créditent pas deux fois", async () => {
  const h = purchaseHarness();
  await h.call(h.payload, h.auth);
  const parentTwo = "families/f/members/parent2";
  h.store.set(parentTwo, {uid: "parent2", role: "parent", active: true});
  const requestId = "purchase-1";
  const call = (uid, operationId) => h.call({familyId: "f", operation: "purchase_approve",
    operationId, requestId}, {auth: {uid, token: {}}});
  const outcomes = await Promise.allSettled([call("parent", "review-a"), call("parent2", "review-b")]);
  assert.equal(outcomes.filter(outcome => outcome.status === "fulfilled").length, 1);
  assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 30);
});

test("un échec du chrono après approbation conserve les minutes créditées", async () => {
  const h = purchaseHarness();
  await h.call(h.payload, h.auth);
  await h.call({familyId: "f", operation: "purchase_approve",
    operationId: "timer-approve", requestId: "purchase-1"}, h.parentAuth);
  const account = h.store.get("families/f/screen_time_accounts/c1");
  account.sessionStart = new Date().toISOString();
  account.sessionMinutes = 20;
  const beforeBalance = account.balanceMinutes;
  await assert.rejects(h.call({familyId: "f", operation: "screen_start",
    operationId: "timer-start", childId: "c1", minutes: 20}, h.parentAuth),
  {code: "failed-precondition"});
  assert.equal(h.store.get("families/f/purchases/purchase-1").status, "approved");
  assert.equal(h.store.get("families/f/screen_time_accounts/c1").balanceMinutes,
    beforeBalance);
});

test("refus rembourse une fois sans minutes; achat ancien ne reçoit jamais un second crédit", async () => {
  const h = purchaseHarness();
  await h.call(h.payload, h.auth);
  const reject = {familyId: "f", operation: "purchase_reject", operationId: "reject-1",
    requestId: "purchase-1"};
  await h.call(reject, h.parentAuth);
  assert.equal(h.store.get("families/f/children/c1").points, 100);
  assert.equal(h.store.has("families/f/screen_time_accounts/c1"), false);
  assert.ok(h.store.get("families/f/purchases/purchase-1").pointsRefundedAt);
  assert.equal((await h.call(reject, h.parentAuth)).idempotent, true);

  const legacy = purchaseHarness();
  legacy.store.set("families/f/purchases/old", {id: "old", status: "pending",
    childId: "c1", cost: 20, screenTimeMinutes: 30, title: "30 min ecran"});
  legacy.store.set("families/f/requests/old", {type: "boutique", status: "pending",
    extra: {purchaseId: "old"}});
  legacy.store.set("families/f/screen_time_accounts/c1", {childId: "c1", balanceMinutes: 30});
  await legacy.call({familyId: "f", operation: "purchase_approve", operationId: "legacy-approve",
    requestId: "old"}, legacy.parentAuth);
  assert.equal(legacy.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 30);

  const restored = purchaseHarness();
  restored.store.set("families/f/purchases/restored", {id: "restored", status: "pending",
    childId: "c1", cost: 20, screenTimeMinutes: 20, settlementVersion: 2});
  const approved = await restored.call({familyId: "f", operation: "purchase_approve",
    operationId: "restore-approve", requestId: "restored"}, restored.parentAuth);
  assert.equal(approved.minutes, 20);
  assert.equal(restored.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 20);
});

test("achats : authentification, famille, owner et rôles responsables vérifiés", async () => {
  const unauthenticated = purchaseHarness();
  await assert.rejects(unauthenticated.call(unauthenticated.payload, {}));
  const otherFamily = purchaseHarness();
  otherFamily.payload.familyId = "other-family";
  await assert.rejects(otherFamily.call(otherFamily.payload, otherFamily.auth));

  const owner = purchaseHarness({role: "owner"});
  owner.store.set("families/f", {ownerUid: "u"});
  owner.store.set("families/f/members/u", {uid: "u", role: "owner", active: true});
  assert.equal((await owner.call(owner.payload, owner.auth)).points, 90);

  for (const role of ["manager", "familyAdmin"]) {
    const managed = purchaseHarness({role});
    managed.auth.auth.token = {email_verified: true,
      firebase: {sign_in_provider: "password"}};
    assert.equal((await managed.call(managed.payload, managed.auth)).points, 90);
    const approved = await managed.call({familyId: "f", operation: "purchase_approve",
      operationId: `review-${role}`, requestId: "purchase-1"}, managed.auth);
    assert.equal(approved.status, "approved");
    const unverified = purchaseHarness({role});
    await assert.rejects(unverified.call(unverified.payload, unverified.auth));
  }

  const missingRequest = purchaseHarness();
  await missingRequest.call(missingRequest.payload, missingRequest.auth);
  missingRequest.store.delete("families/f/requests/purchase-1");
  await assert.rejects(missingRequest.call({familyId: "f", operation: "purchase_approve",
    operationId: "missing-purchase", requestId: "absent"}, missingRequest.parentAuth));
  assert.equal(missingRequest.store.get("families/f/purchases/purchase-1").status, "pending");

  const legacyReject = purchaseHarness();
  legacyReject.store.set("families/f/purchases/legacy-reject", {status: "pending",
    childId: "c1", cost: 10, screenTimeMinutes: 30});
  legacyReject.store.set("families/f/requests/legacy-reject", {type: "boutique",
    status: "pending", extra: {purchaseId: "legacy-reject"}});
  legacyReject.store.set("families/f/screen_time_accounts/c1", {
    childId: "c1", balanceMinutes: 5,
  });
  await legacyReject.call({familyId: "f", operation: "purchase_reject",
    operationId: "legacy-reject-review", requestId: "legacy-reject"}, legacyReject.parentAuth);
  assert.equal(legacyReject.store.get("families/f/screen_time_accounts/c1").balanceMinutes, 0);
  assert.equal(legacyReject.store.get("families/f/children/c1").points, 110);
});
