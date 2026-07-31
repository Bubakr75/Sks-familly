"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  cleanMigrationSecret,
  hashMigrationSecret,
  validateMigrationClaim,
  buildMigratedFamilyData,
  buildMigratedOwnerData,
  buildMigrationCodeIndexData,
} = require("./legacy_family_migration");

const secret =
  "abcdefghijklmnopqrstuvwxyz_ABCDEFGHIJKLMNOPQRSTUVWXYZ-0123456789";

test("cleans and hashes a migration secret", () => {
  assert.equal(cleanMigrationSecret(` ${secret} `), secret);
  assert.equal(hashMigrationSecret(secret).length, 64);

  assert.throws(
    () => cleanMigrationSecret("too-short"),
    /INVALID_MIGRATION_SECRET/
  );
});

test("accepts a valid pending migration claim", () => {
  assert.equal(
    validateMigrationClaim({
      claim: {
        familyId: "family-1",
        status: "pending",
        secretHash: hashMigrationSecret(secret),
        expiresAt: 2000,
      },
      familyId: "family-1",
      secret,
      nowMillis: 1000,
    }),
    true
  );
});

test("rejects expired, used, mismatched and invalid claims", () => {
  const baseClaim = {
    familyId: "family-1",
    status: "pending",
    secretHash: hashMigrationSecret(secret),
    expiresAt: 2000,
  };

  assert.throws(
    () =>
      validateMigrationClaim({
        claim: baseClaim,
        familyId: "family-1",
        secret,
        nowMillis: 2000,
      }),
    /MIGRATION_CLAIM_EXPIRED/
  );

  assert.throws(
    () =>
      validateMigrationClaim({
        claim: {...baseClaim, status: "used"},
        familyId: "family-1",
        secret,
        nowMillis: 1000,
      }),
    /MIGRATION_CLAIM_USED/
  );

  assert.throws(
    () =>
      validateMigrationClaim({
        claim: baseClaim,
        familyId: "family-2",
        secret,
        nowMillis: 1000,
      }),
    /MIGRATION_CLAIM_MISMATCH/
  );

  const wrongSecret =
    "0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

  assert.throws(
    () =>
      validateMigrationClaim({
        claim: baseClaim,
        familyId: "family-1",
        secret: wrongSecret,
        nowMillis: 1000,
      }),
    /INVALID_MIGRATION_SECRET/
  );
});

test("builds the migrated family update", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildMigratedFamilyData({
      ownerUid: "owner-1",
      code: "NEW123",
      timestamp,
      memberCount: 4,
    }),
    {
      ownerUid: "owner-1",
      code: "NEW123",
      schemaVersion: 2,
      migrationStatus: "migrated",
      migratedBy: "owner-1",
      migratedAt: timestamp,
      memberCount: 4,
    }
  );
});

test("builds the migrated owner membership", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildMigratedOwnerData({
      ownerUid: "owner-1",
      timestamp,
    }),
    {
      uid: "owner-1",
      role: "owner",
      childId: null,
      active: true,
      createdAt: timestamp,
      approvedBy: "owner-1",
      approvedAt: timestamp,
      migrationSource: "legacy-family",
    }
  );
});

test("builds the replacement family code index", () => {
  const timestamp = {server: true};

  assert.deepEqual(
    buildMigrationCodeIndexData({
      familyId: "family-1",
      code: "NEW123",
      ownerUid: "owner-1",
      timestamp,
    }),
    {
      familyId: "family-1",
      code: "NEW123",
      ownerUid: "owner-1",
      createdAt: timestamp,
      updatedAt: timestamp,
    }
  );
});