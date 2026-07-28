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
} = require("./secure_child_operations");

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
