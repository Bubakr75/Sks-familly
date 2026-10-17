"use strict";
const {PROJECT_ID, MIGRATION_ID, createPlan, assertReady} = require("./point_scale_migration");

// Construit uniquement une transaction REST ; aucune connexion ni écriture ici.
function buildMigrationCommit({backup, expectedFamilyId, releaseVersion, releaseVerified, now}) {
  if (backup.projectId !== PROJECT_ID || backup.state.familyId !== expectedFamilyId ||
      !/^[^/\u0000-\u001f]{1,128}$/.test(expectedFamilyId)) throw new Error("MIGRATION_TARGET_MISMATCH");
  if (releaseVerified !== true || releaseVersion !== "4.9.0+529") throw new Error("VERIFIED_RELEASE_REQUIRED");
  if ((backup.state.family.pointsScaleVersion ?? 1) === 2) throw new Error("ALREADY_CONVERTED");
  assertReady({...backup.state, family: {...backup.state.family, pointsScaleMigrationReady: true}});
  const plan = createPlan({...backup.state, version: 1});
  if (plan.hash !== backup.plan.hash) throw new Error("BACKUP_PLAN_MISMATCH");
  const root = `projects/${PROJECT_ID}/databases/(default)/documents/families/${expectedFamilyId}`;
  const documents = new Map();
  for (const change of plan.changes) {
    const key = `${change.collection}/${change.id}`;
    if (!documents.has(key)) documents.set(key, []);
    documents.get(key).push(change);
  }
  const value = input => typeof input === "number" ? {integerValue: String(input)} : {stringValue: input};
  const writes = [];
  for (const [key, changes] of documents) {
    const [collection, id] = key.split("/");
    const original = backup.raw.collections[collection]?.find(document => document.name === `${root}/${key}`);
    if (!original?.updateTime) throw new Error("BACKUP_PRECONDITION_REQUIRED");
    const fields = {pointsScaleVersion: {integerValue: "2"}};
    for (const change of changes) {
      const originalValue = original.fields?.[change.field];
      const actual = originalValue?.integerValue !== undefined ? Number(originalValue.integerValue) : originalValue?.stringValue;
      if (actual !== change.before) throw new Error("BACKUP_VALUE_MISMATCH");
      fields[change.field] = value(change.after);
    }
    writes.push({update: {name: `${root}/${key}`, fields}, updateMask: {fieldPaths: Object.keys(fields)},
      currentDocument: {updateTime: original.updateTime}});
  }
  if (backup.raw.family?.name !== root || !backup.raw.family.updateTime) throw new Error("BACKUP_PRECONDITION_REQUIRED");
  const familyFields = {pointsScaleVersion: {integerValue: "2"}, pointsScaleMigrationId: {stringValue: MIGRATION_ID},
    pointsScaleReleaseVersion: {stringValue: releaseVersion}, pointsScaleMigratedAt: {timestampValue: now},
    pointsScaleMigrationReady: {booleanValue: true}};
  writes.push({update: {name: root, fields: familyFields}, updateMask: {fieldPaths: Object.keys(familyFields)},
    currentDocument: {updateTime: backup.raw.family.updateTime}});
  writes.push({update: {name: `${root}/_private_audit/${MIGRATION_ID}`, fields: {
    type: {stringValue: MIGRATION_ID}, planHash: {stringValue: plan.hash},
    createdAt: {timestampValue: now}, releaseVersion: {stringValue: releaseVersion},
    previousValues: {stringValue: JSON.stringify(plan.changes)},
  }}, currentDocument: {exists: false}});
  if (writes.length > 450) throw new Error("MIGRATION_TOO_LARGE_FOR_SINGLE_COMMIT");
  return {writes};
}

module.exports = {buildMigrationCommit};
