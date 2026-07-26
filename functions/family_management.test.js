"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  normalizeManagedFamilyCode,
  cleanManagedDocumentId,
  buildManagedFamilyData,
  buildManagedOwnerData,
  buildFamilyCodeIndexData,
} = require("./family_management");

test("normalizes a managed family code", () => {
  assert.equal(
    normalizeManagedFamilyCode(" abcd12 "),
    "ABCD12"
  );
});

test("rejects unsafe family codes", () => {
  for (const value of ["abc", "ABCDEFGHIJK", "AB/CD", "", null]) {
    assert.throws(
      () => normalizeManagedFamilyCode(value),
      /INVALID_FAMILY_CODE/
    );
  }
});

test("cleans a Firestore document identifier", () => {
  assert.equal(
    cleanManagedDocumentId(" family-123 "),
    "family-123"
  );

  assert.throws(
    () => cleanManagedDocumentId("family/bad"),
    /INVALID_DOCUMENT_ID/
  );
});

test("builds the secured family document", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildManagedFamilyData({
      code: "ABCD12",
      ownerUid: "owner-1",
      createdAt: timestamp,
    }),
    {
      code: "ABCD12",
      createdAt: timestamp,
      memberCount: 1,
      ownerUid: "owner-1",
      schemaVersion: 2,
      migrationStatus: "native",
    }
  );
});

test("builds the active owner membership", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildManagedOwnerData({
      ownerUid: "owner-1",
      createdAt: timestamp,
    }),
    {
      uid: "owner-1",
      role: "owner",
      childId: null,
      active: true,
      createdAt: timestamp,
      approvedBy: "owner-1",
      approvedAt: timestamp,
    }
  );
});

test("builds the private family code index", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildFamilyCodeIndexData({
      familyId: "family-1",
      code: "ABCD12",
      ownerUid: "owner-1",
      timestamp,
    }),
    {
      familyId: "family-1",
      code: "ABCD12",
      ownerUid: "owner-1",
      createdAt: timestamp,
      updatedAt: timestamp,
    }
  );
});