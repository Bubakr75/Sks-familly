"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  OWNER_AUTH_CODES,
  FAMILY_FORMATS,
  familyFormat,
  isAuthenticatedFamilyOwner,
  applyFamilyOwnerRepair,
} = require("./family_owner_authorization");

class TestHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function snapshot(data) {
  return data == null
    ? {exists: false, data: () => undefined}
    : {exists: true, data: () => data};
}

function authorize({
  uid = "owner-1",
  family = {ownerUid: "owner-1", schemaVersion: 2},
  member = {uid: "owner-1", role: "owner", active: true, childId: null},
} = {}) {
  return isAuthenticatedFamilyOwner({
    context: uid ? {auth: {uid}} : {},
    familySnapshot: snapshot(family),
    memberSnapshot: snapshot(member),
    HttpsError: TestHttpsError,
    allowRepair: true,
  });
}

function rejectionReason(callback) {
  try {
    callback();
  } catch (error) {
    return {
      code: error.code,
      reason: error.details && error.details.reason,
    };
  }
  assert.fail("Une erreur d'autorisation était attendue.");
}

test("identifie les formats familiaux sans faire confiance à ownerId", () => {
  assert.equal(
    familyFormat({ownerUid: "owner-1", schemaVersion: 2}),
    FAMILY_FORMATS.MODERN
  );
  assert.equal(
    familyFormat({ownerUid: "owner-1", schemaVersion: 1}),
    FAMILY_FORMATS.HISTORICAL_CANONICAL_OWNER
  );
  assert.equal(
    familyFormat({ownerId: "owner-1"}),
    FAMILY_FORMATS.HISTORICAL_OWNER_ID_ONLY
  );
});

test("retourne des diagnostics non sensibles pour chaque refus", () => {
  assert.deepEqual(
    rejectionReason(() => authorize({uid: null})),
    {
      code: "unauthenticated",
      reason: OWNER_AUTH_CODES.UNAUTHENTICATED,
    }
  );
  assert.deepEqual(
    rejectionReason(() => authorize({uid: "parent-1"})),
    {
      code: "permission-denied",
      reason: OWNER_AUTH_CODES.OWNER_UID_MISMATCH,
    }
  );
  assert.deepEqual(
    rejectionReason(() => authorize({
      member: {uid: "other", role: "owner", active: true},
    })),
    {
      code: "permission-denied",
      reason: OWNER_AUTH_CODES.MEMBER_UID_MISMATCH,
    }
  );
  assert.deepEqual(
    rejectionReason(() => authorize({
      member: {uid: "owner-1", role: "parent", active: true},
    })),
    {
      code: "permission-denied",
      reason: OWNER_AUTH_CODES.ROLE_INCORRECT,
    }
  );
  assert.deepEqual(
    rejectionReason(() => authorize({
      member: {uid: "owner-1", role: "owner", active: false},
    })),
    {
      code: "permission-denied",
      reason: OWNER_AUTH_CODES.MEMBER_INACTIVE,
    }
  );
  assert.deepEqual(
    rejectionReason(() => authorize({
      family: {ownerId: "owner-1"},
      member: null,
    })),
    {
      code: "failed-precondition",
      reason: OWNER_AUTH_CODES.HISTORICAL_FORMAT,
    }
  );
});

test("répare uniquement un propriétaire prouvé par ownerUid", () => {
  const authorization = authorize({
    family: {ownerUid: "owner-1", schemaVersion: 1},
    member: null,
  });

  assert.equal(authorization.authorized, true);
  assert.equal(
    authorization.diagnosticCode,
    OWNER_AUTH_CODES.MEMBER_REPAIRED_MISSING
  );

  const calls = [];
  const transaction = {
    set: (...arguments_) => calls.push(arguments_),
  };
  const timestamp = {server: true};

  assert.equal(
    applyFamilyOwnerRepair({
      transaction,
      memberRef: {path: "families/f/members/owner-1"},
      authorization,
      timestamp,
    }),
    true
  );
  assert.equal(calls.length, 1);
  assert.deepEqual(calls[0][1], {
    uid: "owner-1",
    role: "owner",
    childId: null,
    active: true,
    approvedBy: "owner-1",
    ownerAuthorizationRepair: OWNER_AUTH_CODES.MEMBER_REPAIRED_MISSING,
    ownerAuthorizationRepairedAt: timestamp,
    createdAt: timestamp,
    approvedAt: timestamp,
  });
  assert.deepEqual(calls[0][2], {merge: true});
});

test("un membre propriétaire moderne cohérent ne déclenche aucune écriture", () => {
  const authorization = authorize();
  assert.equal(authorization.diagnosticCode, OWNER_AUTH_CODES.AUTHORIZED);
  assert.equal(authorization.repair, null);
});
