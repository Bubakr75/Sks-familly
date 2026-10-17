"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {createPlan} = require("./point_scale_migration");
const {buildMigrationCommit} = require("./point_scale_commit");

function fixture() {
  const root = "projects/sks-familly-3f205/databases/(default)/documents/families/f";
  const state = {familyId: "f", family: {}, children: [{id: "c", data: {points: 245}}], wallets: [],
    purchases: [], walletTransactions: [], rewards: [{id: "default_screen_time", data: {cost: 50, title: "15 min écran"}}],
    chores: [{id: "chore", data: {points: 50}}]};
  const document = (name, fields) => ({name, fields, updateTime: "2026-10-17T17:00:00Z"});
  const backup = {projectId: "sks-familly-3f205", state, plan: createPlan(state), raw: {
    family: document(root, {}), collections: {
      children: [document(`${root}/children/c`, {points: {integerValue: "245"}})],
      wallets: [], rewards: [document(`${root}/rewards/default_screen_time`, {cost: {integerValue: "50"}, title: {stringValue: "15 min écran"}})],
      chores: [document(`${root}/chores/chore`, {points: {integerValue: "50"}})],
    },
  }};
  return {backup, expectedFamilyId: "f", releaseVerified: true, releaseVersion: "4.9.0+529", now: "2026-10-17T18:00:00Z"};
}

test("la conversion est un commit unique avec préconditions, sauvegarde des valeurs et marqueur anti-rejeu", () => {
  const commit = buildMigrationCommit(fixture());
  assert.equal(commit.writes.length, 5);
  assert.equal(commit.writes[0].update.fields.points.integerValue, "13");
  assert.equal(commit.writes.filter(write => write.update.name.endsWith("rewards/default_screen_time")).length, 1);
  assert.equal(commit.writes.at(-1).currentDocument.exists, false);
  assert.equal(commit.writes.every(write => write.currentDocument.updateTime || write.currentDocument.exists === false), true);
  assert.equal(commit.writes.some(write => write.delete), false);
});

test("une autre famille, une sauvegarde altérée ou une version non vérifiée sont refusées", () => {
  assert.throws(() => buildMigrationCommit({...fixture(), expectedFamilyId: "autre"}), /TARGET_MISMATCH/);
  assert.throws(() => buildMigrationCommit({...fixture(), releaseVerified: false}), /VERIFIED_RELEASE_REQUIRED/);
  const invalid = fixture(); invalid.backup.raw.collections.children[0].fields.points.integerValue = "300";
  assert.throws(() => buildMigrationCommit(invalid), /BACKUP_VALUE_MISMATCH/);
  const repeated = fixture(); repeated.backup.state.family.pointsScaleVersion = 2;
  assert.throws(() => buildMigrationCommit(repeated), /ALREADY_CONVERTED/);
});

test("les anciens éléments supprimés restent intacts, les bonnes actions passent à un point", () => {
  const input = fixture().backup.state;
  input.rewards.push({id: "deleted", data: {isDeleted: true}});
  const plan = createPlan(input);
  assert.equal(plan.changes.some(change => change.id === "deleted"), false);
  assert.equal(plan.changes.find(change => change.collection === "chores").after, 1);
});
