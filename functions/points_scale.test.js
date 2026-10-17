"use strict";
const test = require("node:test");
const assert = require("node:assert/strict");
const {normalizePointsScaleVersion, assertPointsScale} = require("./points_scale");

test("une famille convertie refuse les montants envoyés par une ancienne application", () => {
  assert.doesNotThrow(() => assertPointsScale({}, undefined));
  assert.doesNotThrow(() => assertPointsScale({}, 2));
  assert.doesNotThrow(() => assertPointsScale({pointsScaleVersion: 2}, 2));
  for (const version of [undefined, 1]) {
    assert.throws(() => assertPointsScale({pointsScaleVersion: 2}, version), /UPDATE_REQUIRED/);
  }
});

test("les nouveaux forfaits ne sont disponibles qu’après conversion de la famille", () => {
  assert.throws(() => assertPointsScale({}, 2, {requiresMigration: true}), /MIGRATION_REQUIRED/);
  assert.doesNotThrow(() => assertPointsScale({pointsScaleVersion: 2}, 2, {requiresMigration: true}));
  for (const invalid of [null, 0, 3, "2"]) {
    assert.throws(() => normalizePointsScaleVersion(invalid), /INVALID_POINTS_SCALE_VERSION/);
  }
});
