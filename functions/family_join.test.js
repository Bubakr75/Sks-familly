"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeFamilyCode,
  normalizeJoinRole,
  cleanDocumentId,
  buildJoinRequestData,
  buildApprovedMemberData,
  inspectApprovedMembership,
} = require("./family_join");

test("normalizes a valid family code", () => {
  assert.equal(normalizeFamilyCode(" abcd12 "), "ABCD12");
});

test("rejects an invalid family code", () => {
  assert.throws(() => normalizeFamilyCode("a/"), /INVALID_FAMILY_CODE/);
});

test("accepts only parent or child roles", () => {
  assert.equal(normalizeJoinRole("parent"), "parent");
  assert.equal(normalizeJoinRole("child"), "child");
  assert.throws(() => normalizeJoinRole("owner"), /INVALID_JOIN_ROLE/);
});

test("rejects unsafe document identifiers", () => {
  assert.equal(cleanDocumentId("device-1", "device_id"), "device-1");
  assert.throws(
    () => cleanDocumentId("family/bad", "family_id"),
    /INVALID_FAMILY_ID/
  );
});

test("builds a pending child request without child data access", () => {
  const timestamp = { server: true };

  const data = buildJoinRequestData({
    requesterUid: "uid-child",
    requestedRole: "child",
    requestedChildName: "Adam",
    deviceId: "device-1",
    deviceName: "Tablette",
    createdAt: timestamp,
  });

  assert.equal(data.requesterUid, "uid-child");
  assert.equal(data.requestedRole, "child");
  assert.equal(data.requestedChildName, "Adam");
  assert.equal(data.status, "sent");
  assert.deepEqual(data.readBy, []);
  assert.equal(data.selectedChildId, null);
  assert.equal(data.createdAt, timestamp);
});

test("removes child name from a parent request", () => {
  const data = buildJoinRequestData({
    requesterUid: "uid-parent",
    requestedRole: "parent",
    requestedChildName: "Ignored",
    deviceId: "device-2",
    deviceName: "Telephone",
    createdAt: {},
  });

  assert.equal(data.requestedChildName, null);
});

test("builds an approved child member", () => {
  const timestamp = { server: true };

  const data = buildApprovedMemberData({
    requesterUid: "uid-child",
    requestedRole: "child",
    childId: "child-123",
    approvedBy: "owner-uid",
    createdAt: timestamp,
  });

  assert.deepEqual(data, {
    uid: "uid-child",
    role: "child",
    childId: "child-123",
    active: true,
    createdAt: timestamp,
    approvedBy: "owner-uid",
    approvedAt: timestamp,
  });
});

test("a parent member never receives a childId", () => {
  const data = buildApprovedMemberData({
    requesterUid: "uid-parent",
    requestedRole: "parent",
    childId: "must-not-be-used",
    approvedBy: "owner-uid",
    createdAt: {},
  });

  assert.equal(data.role, "parent");
  assert.equal(data.childId, null);
});

test("an accepted request is ready only with the exact active member", () => {
  const requestData = {
    requesterUid: "uid-parent",
    requestedRole: "parent",
    status: "accepted",
    selectedChildId: null,
  };
  assert.deepEqual(
    inspectApprovedMembership({
      requesterUid: "uid-parent",
      requestData,
      memberData: {
        uid: "uid-parent",
        role: "parent",
        active: true,
        childId: null,
      },
    }),
    {
      ready: true,
      activationState: "ready",
      role: "parent",
      childId: null,
    }
  );
  assert.equal(
    inspectApprovedMembership({
      requesterUid: "uid-parent",
      requestData,
      memberData: null,
    }).activationState,
    "member-missing"
  );
  assert.equal(
    inspectApprovedMembership({
      requesterUid: "uid-parent",
      requestData,
      memberData: {
        uid: "another-uid",
        role: "parent",
        active: true,
      },
    }).activationState,
    "member-uid-mismatch"
  );
  assert.equal(
    inspectApprovedMembership({
      requesterUid: "uid-parent",
      requestData,
      memberData: {
        uid: "uid-parent",
        role: "parent",
        active: false,
      },
    }).activationState,
    "member-inactive"
  );
});
