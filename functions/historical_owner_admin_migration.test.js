"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  parseArgs,
  assertMigrationSafety,
  migrationStateHash,
  validateDryRunState,
  anonymizedReport,
} = require("./historical_owner_admin_migration");

function args(mode = "dry-run") {
  return {
    project: "sks-familly-3f205",
    [mode]: true,
    "family-id": "family-private",
    "expected-old-owner-uid": "old-private",
    "expected-new-owner-uid": "new-private",
  };
}

function state() {
  return {
    familyId: "family-private",
    family: {
      ownerUid: "old-private",
      code: "SECRET",
      schemaVersion: 1,
    },
    oldMember: {uid: "old-private", role: "owner", active: true},
    newMember: {uid: "new-private", role: "parent", active: true},
    codeIndex: {
      familyId: "family-private",
      ownerUid: "old-private",
      code: "SECRET",
    },
  };
}

test("le CLI exige le projet exact, un dry-run ou un apply confirmé", () => {
  assert.doesNotThrow(() => assertMigrationSafety(args()));
  assert.throws(
    () => assertMigrationSafety({...args(), project: "other-project"}),
    /PROJECT_MISMATCH/
  );
  assert.throws(
    () => assertMigrationSafety({...args(), apply: true}),
    /EXACTLY_ONE_MODE/
  );
  assert.throws(
    () => assertMigrationSafety(args("apply")),
    /EXPLICIT_CONFIRMATION/
  );
  const hash = migrationStateHash(state());
  assert.doesNotThrow(() => assertMigrationSafety({
    ...args("apply"),
    confirmation: "APPLIQUER-MIGRATION-PROPRIETAIRE",
    "expected-state-hash": hash,
    "migration-id": "migration-once",
  }));
});

test("les UID attendus et le compte durable sont vérifiés", () => {
  const current = state();
  assert.equal(validateDryRunState({
    family: current.family,
    expectedOldOwnerUid: "old-private",
    expectedNewOwnerUid: "new-private",
    oldMember: current.oldMember,
    newMember: current.newMember,
    newAuthUser: {
      uid: "new-private",
      emailVerified: true,
      providerData: [{providerId: "password"}],
    },
  }), true);
  assert.throws(() => validateDryRunState({
    family: current.family,
    expectedOldOwnerUid: "wrong-old",
    expectedNewOwnerUid: "new-private",
    oldMember: current.oldMember,
    newMember: current.newMember,
    newAuthUser: {
      uid: "new-private",
      emailVerified: true,
      providerData: [{providerId: "password"}],
    },
  }), /OLD_OWNER_STATE_MISMATCH/);
});

test("le rapport anonymisé ne contient ni UID, code ni famille", () => {
  const report = anonymizedReport(state());
  const serialized = JSON.stringify(report);
  assert.equal(report.deletes, 0);
  assert.doesNotMatch(
    serialized,
    /family-private|old-private|new-private|SECRET/
  );
  assert.match(report.stateHash, /^[a-f0-9]{64}$/);
});

test("parse uniquement les arguments explicites", () => {
  assert.deepEqual(
    parseArgs([
      "--project",
      "sks-familly-3f205",
      "--dry-run",
      "--family-id",
      "family",
    ]),
    {
      project: "sks-familly-3f205",
      "dry-run": true,
      "family-id": "family",
    }
  );
});
