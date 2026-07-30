"use strict";

const test = require("node:test");
const assert = require("node:assert/strict");
const {
  ACTIVE_STATUSES,
  isActiveInboxStatus,
} = require("./family_inbox");

test("keeps sent and received requests actionable in the inbox", () => {
  assert.equal(isActiveInboxStatus("pending"), true);
  assert.equal(isActiveInboxStatus("sent"), true);
  assert.equal(isActiveInboxStatus("received"), true);
  assert.equal(isActiveInboxStatus("accepted"), false);
  assert.equal(isActiveInboxStatus("refused"), false);
  assert.equal(isActiveInboxStatus("expired"), false);
  assert.deepEqual(
    [...ACTIVE_STATUSES].sort(),
    ["pending", "received", "sent"]
  );
});
