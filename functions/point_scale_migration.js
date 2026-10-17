"use strict";

const crypto = require("node:crypto");
const fs = require("node:fs/promises");

const PROJECT_ID = "sks-familly-3f205";
const MIGRATION_ID = "points-scale-v2-divide-20";

function convertBalance(value) {
  if (!Number.isSafeInteger(value) || value < 0) {
    throw new Error("INVALID_LEGACY_BALANCE");
  }
  // Évite la perte de précision de value + 19 aux grandes valeurs.
  return Math.floor(value / 20) + (value % 20 === 0 ? 0 : 1);
}

function cleanFamilyId(value) {
  if (typeof value !== "string" || !/^[^/\u0000-\u001f]{1,128}$/.test(value)) {
    throw new Error("EXACT_FAMILY_ID_REQUIRED");
  }
  return value;
}

function createPlan({familyId, children, wallets, rewards = [], chores = [], goals = [], customBadges = [], version = 1}) {
  cleanFamilyId(familyId);
  if (![1, 2].includes(version)) throw new Error("UNKNOWN_POINTS_SCALE");
  const changes = [];
  if (version === 1) {
    for (const [collection, field, records] of [
      ["children", "points", children],
      ["wallets", "balance", wallets],
    ]) {
      if (!Array.isArray(records)) throw new Error("INCOMPLETE_BALANCE_SNAPSHOT");
      const ids = new Set();
      for (const record of records) {
        if (record.data.isDeleted === true) continue;
        cleanFamilyId(record.id);
        if ((record.data.pointsScaleVersion ?? 1) !== 1) {
          throw new Error("MIXED_POINTS_SCALES_REQUIRE_REVIEW");
        }
        if (ids.has(record.id)) throw new Error("DUPLICATE_BALANCE_DOCUMENT");
        ids.add(record.id);
        changes.push({collection, id: record.id, field,
          before: record.data[field], after: convertBalance(record.data[field])});
      }
    }
  }
  if (version === 1) {
    for (const [collection, field, records] of [
      ["rewards", "cost", rewards], ["chores", "points", chores],
      ["goals", "targetPoints", goals.filter(record => record.data.completed !== true)],
      ["custom_badges", "requiredPoints", customBadges],
    ]) {
      const ids = new Set();
      for (const record of records) {
        if (record.data.isDeleted === true) continue;
        cleanFamilyId(record.id);
        if (ids.has(record.id)) throw new Error("DUPLICATE_BALANCE_DOCUMENT");
        ids.add(record.id);
        if ((record.data.pointsScaleVersion ?? 1) !== 1) throw new Error("MIXED_POINTS_SCALES_REQUIRE_REVIEW");
        const before = record.data[field];
        const after = collection === "chores" ? 1 : convertBalance(before);
        changes.push({collection, id: record.id, field, before, after});
        if (collection === "rewards" && record.id === "default_screen_time") {
          changes[changes.length - 1].after = 3;
          changes.push({collection, id: record.id, field: "title", before: record.data.title,
            after: "30 min d’écran"});
        }
      }
    }
  }
  changes.sort((a, b) => `${a.collection}/${a.id}`.localeCompare(`${b.collection}/${b.id}`));
  const payload = {projectId: PROJECT_ID, familyId, migrationId: MIGRATION_ID,
    fromVersion: version, toVersion: 2, divisor: 20, rounding: "ceil", changes};
  return {...payload, hash: crypto.createHash("sha256").update(JSON.stringify(payload)).digest("hex")};
}

async function readState(db, familyId) {
  cleanFamilyId(familyId);
  const family = db.collection("families").doc(familyId);
  const [familySnapshot, children, wallets, purchases] = await Promise.all([
    family.get(), family.collection("children").get(), family.collection("wallets").get(),
    family.collection("purchases").get(),
  ]);
  if (!familySnapshot.exists) throw new Error("FAMILY_NOT_FOUND");
  const documents = snapshot => snapshot.docs.map(doc => ({id: doc.id, data: doc.data()}));
  const walletTransactions = (await Promise.all(wallets.docs.map(async wallet => {
    const operations = await wallet.ref.collection("operations").get();
    return documents(operations).map(operation => ({...operation, walletId: wallet.id}));
  }))).flat();
  return {familyId, family: familySnapshot.data(), children: documents(children),
    wallets: documents(wallets), purchases: documents(purchases),
    walletTransactions};
}

function assertReady(state) {
  // La conversion doit accompagner le nouveau client, jamais précéder sa mise en service.
  if (state.family.pointsScaleMigrationReady !== true) {
    throw new Error("NEW_POINTS_SCALE_ROLLOUT_NOT_READY");
  }
  if (state.purchases.some(item => item.data.status === "pending")) {
    throw new Error("LEGACY_PURCHASES_MUST_BE_SETTLED_FIRST");
  }
  // Un ancien crédit annulable peut rendre des points dans l'ancien barème.
  if (state.walletTransactions.some(({data}) => data.type === "credit" &&
      data.pointsDebited === true && data.status !== "reversed")) {
    throw new Error("LEGACY_WALLET_REVERSALS_MUST_BE_SETTLED_FIRST");
  }
}

async function prepareBackup({db, familyId, backupPath}) {
  const state = await readState(db, familyId);
  const plan = createPlan({...state, version: state.family.pointsScaleVersion ?? 1});
  const backup = {createdAt: new Date().toISOString(), plan, state};
  // Création exclusive : une sauvegarde existante n'est jamais écrasée.
  await fs.writeFile(backupPath, JSON.stringify(backup, null, 2), {flag: "wx", mode: 0o600});
  return {plan, backupPath};
}

module.exports = {PROJECT_ID, MIGRATION_ID, convertBalance, createPlan, readState, assertReady, prepareBackup};
