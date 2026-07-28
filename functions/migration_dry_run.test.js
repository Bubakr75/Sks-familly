"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  assertEmulatorDryRun,
  anonymizedBucket,
  buildMigrationPlan,
} = require("./migration_dry_run");

test("refuse tout projet réel, absence d'émulateur ou mode écriture", () => {
  const valid = {
    argv: ["--dry-run"],
    env: {FIRESTORE_EMULATOR_HOST: "127.0.0.1:8080"},
    projectId: "demo-sks-migration",
  };
  assert.doesNotThrow(() => assertEmulatorDryRun(valid));
  assert.throws(() => assertEmulatorDryRun({...valid, projectId: "sks-familly-3f205"}), /DEMO_PROJECT/);
  assert.throws(() => assertEmulatorDryRun({...valid, env: {}}), /EMULATOR/);
  assert.throws(() => assertEmulatorDryRun({...valid, argv: ["--apply"]}), /DRY_RUN/);
});

test("le plan est idempotent et le rapport ne contient aucune donnée privée", () => {
  const input = [
    {id: "private-family-id", data: {code: "SECRET"}, memberCount: 0},
    {id: "managed", data: {ownerUid: "private-uid"}, memberCount: 1},
  ];
  const first = buildMigrationPlan(input);
  const second = buildMigrationPlan(input);
  assert.deepEqual(first, second);
  assert.equal(first.report.eligible, 1);
  const serialized = JSON.stringify(first.report);
  assert.doesNotMatch(serialized, /private-family-id|SECRET|private-uid|managed/);
  assert.equal(anonymizedBucket("private-family-id").length, 2);
});
