"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {isJoinSubmission, parentRecipientUids, createJoinNotificationHandler} =
  require("./join_notifications");
class HttpsError extends Error {}
const doc = (id, data) => ({id, exists: true, data: () => data});
test("un rappel pending notifie une fois sans redéclenchement lors du marquage", () => {
  assert.equal(isJoinSubmission({status: "sent"},
    {status: "sent", notificationRevision: 1}), true);
  assert.equal(isJoinSubmission({status: "sent", notificationRevision: 1},
    {status: "sent", notificationRevision: 1, notificationEventId: "event"}), false);
});
const familySnapshot = doc("family", {ownerUid: "owner", schemaVersion: 2});

test("création et nouvelle soumission après refus déclenchent une alerte", () => {
  assert.equal(isJoinSubmission(null, {status: "sent"}), true);
  for (const status of ["refused", "rejected", "expired"]) {
    assert.equal(isJoinSubmission({status}, {status: "sent"}), true);
  }
  for (const status of ["pending", "sent", "received"]) {
    assert.equal(isJoinSubmission({status}, {status: "received"}), false);
  }
  assert.equal(isJoinSubmission({status: "sent"}, {status: "accepted"}), false);
});

test("le propriétaire canonique reste destinataire si sa fiche manque ou est incomplète", async () => {
  for (const members of [[], [doc("owner", {})]]) {
    const uids = await parentRecipientUids({familySnapshot, members, HttpsError});
    assert.deepEqual([...uids], ["owner"]);
  }
});

test("ne contourne pas une désactivation ni une identité propriétaire incohérente", async () => {
  for (const member of [{active: false}, {uid: "other"}, {role: "child"}]) {
    const uids = await parentRecipientUids({familySnapshot,
      members: [doc("owner", member)], HttpsError});
    assert.equal(uids.size, 0);
  }
});

test("un enfant ou un gestionnaire non vérifié ne reçoit pas les alertes", async () => {
  const members = [doc("child", {uid: "child", active: true, role: "child"}),
    doc("manager", {uid: "manager", active: true, role: "manager"}),
    doc("parent", {uid: "parent", active: true, role: "parent"})];
  const admin = {auth: () => ({getUser: async () => ({emailVerified: false})})};
  const uids = await parentRecipientUids({familySnapshot, members, admin, HttpsError});
  assert.deepEqual([...uids], ["owner", "parent"]);
});

function fixture({currentOverride = {}, devices, members = []} = {}) {
  const req = {status: "sent", deviceId: "iphone", createdAt: {seconds: 10, nanoseconds: 123}};
  const current = {...req, ...currentOverride};
  const sends = [];
  const ref = {};
  const familyRef = {get: async () => familySnapshot, collection: (name) => ({
    get: async () => ({docs: name === "members" ? members : devices || [
      doc("android", {uid: "owner", token: "parent-token"}),
      doc("iphone", {uid: "owner", token: "requester-token"}),
      doc("child", {uid: "child", token: "child-token"}),
      doc("disabled", {uid: "owner", disabled: true, token: "disabled-token"}),
      doc("empty", {uid: "owner", token: ""}),
      doc("duplicate", {uid: "owner", token: "parent-token"})]})})};
  const db = {collection: () => ({doc: () => familyRef}),
    runTransaction: async (fn) => fn({
      get: async () => ({exists: true, data: () => current}),
      update: (_, patch) => Object.assign(current, patch)})};
  const admin = {messaging: () => ({sendEachForMulticast: async (message) => {
    sends.push(message);
    return {successCount: message.tokens.length, failureCount: 0,
      responses: message.tokens.map(() => ({success: true}))};
  }})};
  const handle = createJoinNotificationHandler({db, admin, HttpsError});
  return {sends, current, run: () => handle({ref, data: () => req}, {
    eventId: "event", params: {familyId: "family", requestId: "requester"}})};
}

test("une demande iPhone notifie Android sans token push sur l’iPhone", async () => {
  const f = fixture();
  await f.run();
  assert.equal(f.sends.length, 1);
  assert.deepEqual(f.sends[0].tokens, ["parent-token"]);
  assert.equal(f.sends[0].data.type, "join_request");
  assert.equal(f.sends[0].android.priority, "high");
  await f.run();
  assert.equal(f.sends.length, 1, "un rejeu ne doit pas doubler la notification");
});

test("un ancien événement ne marque pas une nouvelle demande et ne la notifie pas", async () => {
  const f = fixture({currentOverride: {createdAt: {seconds: 20, nanoseconds: 0}}});
  await f.run();
  assert.equal(f.sends.length, 0);
  assert.equal(f.current.notificationEventId, undefined);
});

test("une demande déjà acceptée ne déclenche plus d’alerte", async () => {
  const f = fixture({currentOverride: {status: "accepted"}});
  await f.run();
  assert.equal(f.sends.length, 0);
});

test("un événement ancien ne consomme pas le rappel d’une version plus récente", async () => {
  const f = fixture({currentOverride: {notificationRevision: 1}});
  await f.run();
  assert.equal(f.sends.length, 0);
  assert.equal(f.current.notificationEventId, undefined);
});

test("sans destinataire, la demande reste disponible sans être marquée envoyée", async () => {
  const f = fixture({devices: []});
  await f.run();
  assert.equal(f.sends.length, 0);
  assert.equal(f.current.notificationEventId, undefined);
});
