"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  MAX_WALLET_AMOUNT,
  normalizeWalletOperation,
  isAuthorizedWalletParent,
  buildWalletOperationData,
  isMatchingWalletOperation,
  calculateWalletBalance,
} = require("./wallet");

test("normalizes a valid wallet operation", () => {
  assert.deepEqual(
    normalizeWalletOperation({
      familyId: " family-1 ",
      childId: "child-1",
      operationId: "operation-1",
      type: "credit",
      amount: 25,
      reason: " Argent de poche ",
    }),
    {
      familyId: "family-1",
      childId: "child-1",
      operationId: "operation-1",
      type: "credit",
      amount: 25,
      reason: "Argent de poche",
    }
  );
});

test("rejects invalid amounts and reasons", () => {
  const base = {
    familyId: "family-1",
    childId: "child-1",
    operationId: "operation-1",
    type: "credit",
    amount: 1,
    reason: "Motif",
  };

  for (const amount of [0, -1, 1.5, MAX_WALLET_AMOUNT + 1]) {
    assert.throws(
      () => normalizeWalletOperation({...base, amount}),
      /INVALID_AMOUNT/
    );
  }
  assert.throws(
    () => normalizeWalletOperation({...base, reason: "  "}),
    /INVALID_REASON/
  );
});

test("authorizes only active parents and the real owner", () => {
  const family = {ownerUid: "owner-1"};

  assert.equal(
    isAuthorizedWalletParent({
      uid: "parent-1",
      family,
      member: {uid: "parent-1", role: "parent", active: true},
    }),
    true
  );
  assert.equal(
    isAuthorizedWalletParent({
      uid: "owner-1",
      family,
      member: {uid: "owner-1", role: "owner", active: true},
    }),
    true
  );
  assert.equal(
    isAuthorizedWalletParent({
      uid: "child-1",
      family,
      member: {uid: "child-1", role: "child", active: true},
    }),
    false
  );
  assert.equal(
    isAuthorizedWalletParent({
      uid: "fake-owner",
      family,
      member: {uid: "fake-owner", role: "owner", active: true},
    }),
    false
  );
});

test("builds immutable credit and debit ledger entries", () => {
  const timestamp = {server: true};
  const base = {
    familyId: "family-1",
    childId: "child-1",
    operationId: "operation-1",
    amount: 10,
    reason: "Motif",
  };

  assert.equal(
    buildWalletOperationData({
      operation: {...base, type: "credit"},
      actorUid: "parent-1",
      balanceAfter: 30,
      timestamp,
    }).delta,
    10
  );
  assert.equal(
    buildWalletOperationData({
      operation: {...base, type: "debit"},
      actorUid: "parent-1",
      balanceAfter: 10,
      timestamp,
    }).delta,
    -10
  );
});

test("accepts only an identical replay for an operationId", () => {
  const operation = {
    childId: "child-1",
    type: "credit",
    amount: 10,
    reason: "Motif",
  };
  const existing = {
    ...operation,
    actorUid: "parent-1",
    balanceAfter: 20,
  };

  assert.equal(
    isMatchingWalletOperation({
      existing,
      operation,
      actorUid: "parent-1",
    }),
    true
  );
  assert.equal(
    isMatchingWalletOperation({
      existing,
      operation: {...operation, amount: 11},
      actorUid: "parent-1",
    }),
    false
  );
  assert.equal(
    isMatchingWalletOperation({
      existing,
      operation,
      actorUid: "parent-2",
    }),
    false
  );
});

test("never allows a negative wallet balance", () => {
  assert.equal(
    calculateWalletBalance({
      currentBalance: 20,
      type: "credit",
      amount: 5,
    }),
    25
  );
  assert.equal(
    calculateWalletBalance({
      currentBalance: 20,
      type: "debit",
      amount: 5,
    }),
    15
  );
  assert.throws(
    () => calculateWalletBalance({
      currentBalance: 4,
      type: "debit",
      amount: 5,
    }),
    /INSUFFICIENT_BALANCE/
  );
});


test("wallet credit atomically consumes child behavior points", () => {
  const {
    calculateChildPointsAfterWalletCredit,
  } = require("./wallet");

  assert.equal(
    calculateChildPointsAfterWalletCredit({
      currentChildPoints: 25,
      type: "credit",
      amount: 10,
    }),
    15
  );

  assert.equal(
    calculateChildPointsAfterWalletCredit({
      currentChildPoints: 25,
      type: "debit",
      amount: 10,
    }),
    25
  );

  assert.throws(
    () => calculateChildPointsAfterWalletCredit({
      currentChildPoints: 5,
      type: "credit",
      amount: 10,
    }),
    /INSUFFICIENT_CHILD_POINTS/
  );
});
