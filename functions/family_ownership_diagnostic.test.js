"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  DIAGNOSTIC_CODES,
  shortFingerprint,
  safeMemberState,
  classifyOwnership,
  diagnosticStateFingerprint,
} = require("./family_ownership_diagnostic");

test("propriétaire moderne cohérent et réparation canonique distingués", () => {
  const family = {ownerUid: "current", schemaVersion: 2};
  const coherent = classifyOwnership({
    family,
    currentUid: "current",
    currentMember: {uid: "current", role: "owner", active: true},
    ownerMember: {uid: "current", role: "owner", active: true},
  });
  assert.equal(coherent.code, DIAGNOSTIC_CODES.OWNER_COHERENT);
  assert.equal(coherent.automaticRepairAllowed, false);

  const missing = classifyOwnership({
    family,
    currentUid: "current",
    currentMember: null,
    ownerMember: null,
  });
  assert.equal(missing.code, DIAGNOSTIC_CODES.OWNER_MEMBER_MISSING);
  assert.equal(missing.automaticRepairAllowed, true);
});

test("UID historique différent interdit toute réparation automatique", () => {
  const result = classifyOwnership({
    family: {ownerUid: "old-anonymous", schemaVersion: 1},
    currentUid: "current-durable",
    currentMember: {uid: "current-durable", role: "parent", active: true},
    ownerMember: {uid: "old-anonymous", role: "owner", active: true},
  });
  assert.equal(result.code, DIAGNOSTIC_CODES.HISTORICAL_OWNER_MISMATCH);
  assert.equal(result.proofLevel, "insufficient");
  assert.equal(result.automaticRepairAllowed, false);
});

test("ownerId historique seul n'est jamais une preuve", () => {
  const result = classifyOwnership({
    family: {ownerId: "current", schemaVersion: 1},
    currentUid: "current",
    currentMember: null,
    ownerMember: null,
  });
  assert.equal(result.code, DIAGNOSTIC_CODES.HISTORICAL_OWNER_ID_ONLY);
  assert.equal(result.automaticRepairAllowed, false);
});

test("le rapport utilise seulement des empreintes non réversibles", () => {
  const input = {
    familyId: "private-family",
    family: {ownerUid: "old-private"},
    currentUid: "new-private",
    currentMember: null,
    ownerMember: {uid: "old-private", role: "owner", active: true},
  };
  const fingerprint = diagnosticStateFingerprint(input);
  assert.match(fingerprint, /^[a-f0-9]{64}$/);
  assert.equal(shortFingerprint(input.familyId).length, 12);
  assert.doesNotMatch(
    `${fingerprint}${shortFingerprint(input.familyId)}`,
    /private-family|old-private|new-private/
  );
  assert.equal(safeMemberState(null, "uid"), "missing");
});
