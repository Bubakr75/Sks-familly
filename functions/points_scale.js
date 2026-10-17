"use strict";

function normalizePointsScaleVersion(value) {
  if (value === undefined) return undefined;
  if (value !== 1 && value !== 2) throw new Error("INVALID_POINTS_SCALE_VERSION");
  return value;
}

function assertPointsScale(family, version, {requiresMigration = false} = {}) {
  if (requiresMigration && family.pointsScaleVersion !== 2) {
    throw new Error("POINTS_SCALE_MIGRATION_REQUIRED");
  }
  if (family.pointsScaleVersion === 2 && version !== 2) {
    throw new Error("POINTS_SCALE_UPDATE_REQUIRED");
  }
}

module.exports = {normalizePointsScaleVersion, assertPointsScale};
