"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  FAMILY_PERMISSIONS,
  authorizeFamilyPermission,
  isDurableVerifiedAuth,
} = require("./family_access_control");

class TestHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function snapshot(data) {
  return {
    exists: data != null,
    data: () => data,
  };
}

function context(uid, {durable = false, spoofedRole} = {}) {
  return {
    auth: {
      uid,
      token: {
        email_verified: durable,
        firebase: {
          sign_in_provider: durable ? "password" : "anonymous",
        },
        role: spoofedRole,
      },
    },
  };
}

const family = snapshot({ownerUid: "owner-a", schemaVersion: 2});

test("owner can manage managers without trusting client fields", () => {
  const result = authorizeFamilyPermission({
    context: context("owner-a", {spoofedRole: "child"}),
    familySnapshot: family,
    memberSnapshot: snapshot({
      uid: "owner-a",
      role: "owner",
      active: true,
      childId: null,
    }),
    HttpsError: TestHttpsError,
    permission: FAMILY_PERMISSIONS.MANAGE_MANAGERS,
  });
  assert.equal(result.role, "owner");
});

test("verified durable manager has only manager permissions", () => {
  const managerContext = context("manager-a", {durable: true});
  const member = snapshot({
    uid: "manager-a",
    role: "manager",
    active: true,
  });
  assert.equal(isDurableVerifiedAuth(managerContext), true);
  assert.equal(
    authorizeFamilyPermission({
      context: managerContext,
      familySnapshot: family,
      memberSnapshot: member,
      HttpsError: TestHttpsError,
      permission: FAMILY_PERMISSIONS.MANAGE_JOIN_REQUESTS,
    }).role,
    "manager"
  );
  assert.throws(
    () => authorizeFamilyPermission({
      context: managerContext,
      familySnapshot: family,
      memberSnapshot: member,
      HttpsError: TestHttpsError,
      permission: FAMILY_PERMISSIONS.MANAGE_MANAGERS,
    }),
    (error) => error.code === "permission-denied"
  );
});

test("anonymous manager, parent, child and inactive member are refused", () => {
  const cases = [
    {
      uid: "manager-a",
      durable: false,
      member: {uid: "manager-a", role: "manager", active: true},
    },
    {
      uid: "parent-a",
      durable: true,
      member: {uid: "parent-a", role: "parent", active: true},
    },
    {
      uid: "child-a",
      durable: true,
      member: {uid: "child-a", role: "child", active: true},
    },
    {
      uid: "inactive-a",
      durable: true,
      member: {uid: "inactive-a", role: "manager", active: false},
    },
    {
      uid: "mismatch-a",
      durable: true,
      member: {uid: "other-a", role: "manager", active: true},
    },
  ];
  for (const item of cases) {
    assert.throws(
      () => authorizeFamilyPermission({
        context: context(item.uid, {durable: item.durable}),
        familySnapshot: family,
        memberSnapshot: snapshot(item.member),
        HttpsError: TestHttpsError,
        permission: FAMILY_PERMISSIONS.MANAGE_JOIN_REQUESTS,
      }),
      (error) => error.code === "permission-denied"
    );
  }
});
