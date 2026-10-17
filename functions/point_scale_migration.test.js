"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {convertBalance, createPlan, readState, assertReady} = require("./point_scale_migration");

test("le taux approuvé conserve les reliquats positifs", () => {
  for (const [before, after] of [[0, 0], [1, 1], [19, 1], [20, 1], [21, 2], [50, 3], [100, 5], [200, 10], [300, 15]]) {
    assert.equal(convertBalance(before), after);
  }
  assert.equal(convertBalance(Number.MAX_SAFE_INTEGER), 450359962737050);
  for (const value of [-1, 2.5, "200", undefined, Infinity]) {
    assert.throws(() => convertBalance(value), /INVALID_LEGACY_BALANCE/);
  }
});

test("le plan cible une seule famille, ses points et sa cagnotte", () => {
  const input = {familyId: "famille-test", children: [{id: "enfant", data: {points: 200, name: "Test"}}], wallets: [{id: "enfant", data: {balance: 50}}]};
  const original = JSON.stringify(input);
  const plan = createPlan(input);
  assert.equal(plan.changes[0].after, 10);
  assert.equal(plan.changes[1].after, 3);
  assert.equal(plan.hash, createPlan(input).hash);
  assert.equal(JSON.stringify(input), original);
  assert.equal(plan.changes.some(item => item.collection === "history"), false);
});

test("un solde déjà converti ne peut pas être divisé une seconde fois", () => {
  assert.deepEqual(createPlan({familyId: "famille-test", version: 2}).changes, []);
  assert.throws(() => createPlan({familyId: "famille-test", version: 3}), /UNKNOWN_POINTS_SCALE/);
  assert.throws(() => createPlan({familyId: ""}), /EXACT_FAMILY_ID_REQUIRED/);
  assert.throws(() => createPlan({familyId: "famille-test", children: [{id: "a", data: {points: 10, pointsScaleVersion: 2}}], wallets: []}), /MIXED_POINTS_SCALES/);
});

test("la lecture reste limitée à la famille et retrouve les opérations dans chaque cagnotte", async () => {
  const reads = [];
  const ref = path => ({
    collection: name => ref(`${path}/${name}`),
    doc: id => ref(`${path}/${id}`),
    get: async () => {
      reads.push(path);
      if (path === "families/f") return {exists: true, data: () => ({})};
      if (path === "families/f/wallets") return {docs: [{id: "a", data: () => ({balance: 20}), ref: ref(`${path}/a`)}]};
      if (path === "families/f/wallets/a/operations") return {docs: [{id: "credit", data: () => ({type: "credit", amount: 20, pointsDebited: true})}]};
      return {docs: []};
    },
  });
  const state = await readState({collection: name => ref(name)}, "f");
  assert.equal(state.walletTransactions[0].walletId, "a");
  assert.equal(state.walletTransactions[0].data.pointsDebited, true);
  assert.equal(reads.every(path => path === "families/f" || path.startsWith("families/f/")), true);
  assert.equal(reads.includes("families/f/wallet_transactions"), false);
});

test("le contrôle refuse une conversion avant la nouvelle version ou avec anciens achats en attente", () => {
  const state = {family: {}, purchases: [], walletTransactions: []};
  assert.throws(() => assertReady(state), /ROLLOUT_NOT_READY/);
  state.family.pointsScaleMigrationReady = true;
  assert.doesNotThrow(() => assertReady(state));
  state.purchases.push({data: {status: "pending"}});
  assert.throws(() => assertReady(state), /PURCHASES_MUST_BE_SETTLED/);
  state.purchases = [];
  state.walletTransactions.push({data: {type: "credit", pointsDebited: true}});
  assert.throws(() => assertReady(state), /REVERSALS_MUST_BE_SETTLED/);
  state.walletTransactions[0].data.status = "reversed";
  assert.doesNotThrow(() => assertReady(state));
});
