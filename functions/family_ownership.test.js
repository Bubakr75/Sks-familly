"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");

const {
  TRANSFER_CONFIRMATION,
  normalizedVerifiedEmail,
  requireDurableRecentAuth,
  emailHash,
  newRecoverySecret,
  hashRecoverySecret,
  recoverySecretMatches,
  targetRoleAfterTransfer,
} = require("./family_ownership");

class TestHttpsError extends Error {
  constructor(code, message, details) {
    super(message);
    this.code = code;
    this.details = details;
  }
}

function context(overrides = {}) {
  return {
    auth: {
      uid: "owner-a",
      token: {
        email: "Owner@Example.test",
        email_verified: true,
        auth_time: 990,
        firebase: {sign_in_provider: "password"},
        ...overrides,
      },
    },
  };
}

test("le transfert exige un compte durable vérifié et récent", () => {
  assert.equal(
    requireDurableRecentAuth(context(), TestHttpsError, 1000),
    "owner-a"
  );
  assert.equal(
    normalizedVerifiedEmail(context()),
    "owner@example.test"
  );
  assert.throws(
    () => requireDurableRecentAuth(
      context({auth_time: 100}),
      TestHttpsError,
      1000
    ),
    (error) => error.details.reason === "AUTH_RECENT_REQUIRED"
  );
  assert.throws(
    () => requireDurableRecentAuth(
      context({
        email_verified: false,
        firebase: {sign_in_provider: "anonymous"},
      }),
      TestHttpsError,
      1000
    ),
    (error) => error.code === "failed-precondition"
  );
});

test("le code de récupération est fort, hashé et vérifié en temps constant", () => {
  const secret = newRecoverySecret();
  assert.ok(secret.length >= 40);
  const record = hashRecoverySecret(secret, Buffer.alloc(16, 7));
  assert.equal(record.algorithm, "scrypt-v1");
  assert.equal(Object.values(record).includes(secret), false);
  assert.equal(recoverySecretMatches(secret, record), true);
  assert.equal(recoverySecretMatches(`${secret}x`, record), false);
  assert.equal(recoverySecretMatches(secret, {...record, algorithm: "raw"}), false);
});

test("le hash email ne révèle jamais l'adresse", () => {
  const hash = emailHash("owner@example.test");
  assert.match(hash, /^[a-f0-9]{64}$/);
  assert.equal(hash.includes("owner"), false);
});

test("l'ancien propriétaire devient uniquement manager ou parent", () => {
  assert.equal(targetRoleAfterTransfer("manager"), "manager");
  assert.equal(targetRoleAfterTransfer("parent"), "parent");
  for (const role of ["owner", "child", "familyAdmin", null]) {
    assert.throws(() => targetRoleAfterTransfer(role));
  }
  assert.equal(TRANSFER_CONFIRMATION, "TRANSFERER LA PROPRIETE");
});
