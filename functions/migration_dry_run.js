"use strict";

const crypto = require("node:crypto");

function assertEmulatorDryRun({argv, env, projectId}) {
  if (!argv.includes("--dry-run") || argv.includes("--apply")) {
    throw new Error("DRY_RUN_REQUIRED");
  }
  if (!env.FIRESTORE_EMULATOR_HOST) {
    throw new Error("FIRESTORE_EMULATOR_REQUIRED");
  }
  if (typeof projectId !== "string" || !projectId.startsWith("demo-")) {
    throw new Error("DEMO_PROJECT_REQUIRED");
  }
}

function anonymizedBucket(familyId) {
  return crypto.createHash("sha256").update(`sks-dry-run:${familyId}`)
    .digest("hex").slice(0, 2);
}

function buildMigrationPlan(families) {
  const report = {
    mode: "dry-run",
    scanned: 0,
    eligible: 0,
    alreadyManaged: 0,
    hasMembers: 0,
    invalid: 0,
    buckets: {},
  };
  const eligibleFamilyIds = [];
  for (const item of families) {
    report.scanned += 1;
    const familyId = item && item.id;
    const data = item && item.data;
    if (typeof familyId !== "string" || !data || typeof data !== "object") {
      report.invalid += 1;
      continue;
    }
    if (data.ownerUid || data.schemaVersion === 2 ||
        data.migrationStatus === "migrated") {
      report.alreadyManaged += 1;
      continue;
    }
    if (item.memberCount > 0) {
      report.hasMembers += 1;
      continue;
    }
    report.eligible += 1;
    eligibleFamilyIds.push(familyId);
    const bucket = anonymizedBucket(familyId);
    report.buckets[bucket] = (report.buckets[bucket] || 0) + 1;
  }
  return {eligibleFamilyIds, report};
}

async function scanEmulator(db) {
  const snapshot = await db.collection("families").get();
  const families = [];
  for (const doc of snapshot.docs) {
    const members = await doc.ref.collection("members").limit(1).get();
    families.push({
      id: doc.id,
      data: doc.data(),
      memberCount: members.empty ? 0 : 1,
    });
  }
  return buildMigrationPlan(families);
}

async function main() {
  const admin = require("firebase-admin");
  const projectId = process.env.GCLOUD_PROJECT ||
    process.env.GOOGLE_CLOUD_PROJECT || "";
  assertEmulatorDryRun({
    argv: process.argv.slice(2),
    env: process.env,
    projectId,
  });
  if (admin.apps.length === 0) admin.initializeApp({projectId});
  const {report} = await scanEmulator(admin.firestore());
  process.stdout.write(`${JSON.stringify(report)}\n`);
}

if (require.main === module) {
  main().catch((error) => {
    process.stderr.write(`Migration dry-run refusée: ${error.message}\n`);
    process.exitCode = 1;
  });
}

module.exports = {
  assertEmulatorDryRun,
  anonymizedBucket,
  buildMigrationPlan,
  scanEmulator,
};
