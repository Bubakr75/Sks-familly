"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  authUserIsDurableVerified,
  buildManagerPatch,
  buildParentPatch,
} = require("./family_managers");

test("a manager target must have a verified durable provider", () => {
  assert.equal(
    authUserIsDurableVerified({
      emailVerified: true,
      providerData: [{providerId: "password"}],
    }),
    true
  );
  assert.equal(
    authUserIsDurableVerified({
      emailVerified: false,
      providerData: [{providerId: "password"}],
    }),
    false
  );
  assert.equal(
    authUserIsDurableVerified({
      emailVerified: true,
      providerData: [{providerId: "anonymous"}],
    }),
    false
  );
});

test("manager promotion and revocation never alter ownership", () => {
  const timestamp = {server: true};
  const manager = buildManagerPatch({
    ownerUid: "owner-a",
    timestamp,
  });
  assert.equal(manager.role, "manager");
  assert.equal(manager.managerGrantedBy, "owner-a");
  assert.equal(Object.hasOwn(manager, "ownerUid"), false);

  const parent = buildParentPatch({timestamp});
  assert.equal(parent.role, "parent");
  assert.equal(Object.hasOwn(parent, "ownerUid"), false);
});
