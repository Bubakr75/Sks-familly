"use strict";

const fs = require("node:fs");
const path = require("node:path");
const test = require("node:test");
const assert = require("node:assert/strict");

const {
  initializeTestEnvironment,
  assertFails,
  assertSucceeds,
} = require("@firebase/rules-unit-testing");
const {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} = require("firebase/firestore");

const PROJECT_ID = "demo-sks-family";
const FAMILY_A = "family-a";
const FAMILY_B = "family-b";

const parentWritableCollections = [
  "goals",
  "punishments",
  "notes",
  "immunities",
  "trades",
  "tribunal",
  "custom_badges",
  "screen_time",
  "screen_time_accounts",
  "chores",
  "rewards",
  "purchases",
];

const memberReadableCollections = [
  "children",
  "history",
  ...parentWritableCollections,
];

let testEnv;

function familyRef(db, familyId = FAMILY_A) {
  return doc(db, "families", familyId);
}

function familyCollectionRef(db, collectionName, familyId = FAMILY_A) {
  return collection(db, "families", familyId, collectionName);
}

function businessRef(
  db,
  collectionName,
  documentId = "document-1",
  familyId = FAMILY_A
) {
  return doc(db, "families", familyId, collectionName, documentId);
}

function requestData(id, childId = "child-1", overrides = {}) {
  return {
    id,
    type: "bonus",
    childId,
    requestedBy: "Enfant",
    text: "Demande de test",
    amount: 5,
    status: "pending",
    createdAt: "2026-07-28T12:00:00.000Z",
    extra: {},
    readBy: [],
    lastModifiedBy: "device-test",
    ...overrides,
  };
}

function fcmData(uid, deviceId, token = "token-test") {
  return {
    token,
    deviceId,
    uid,
    platform: "android",
    updatedAt: new Date("2026-07-28T12:00:00.000Z"),
  };
}

async function seedFirestore() {
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();

    await setDoc(familyRef(db), {
      ownerUid: "owner-a",
      code: "AAAAAA",
    });
    await setDoc(familyRef(db, FAMILY_B), {
      ownerUid: "owner-b",
      code: "BBBBBB",
    });

    const familyAMembers = [
      ["owner-a", {uid: "owner-a", role: "owner", active: true}],
      ["parent-a", {uid: "parent-a", role: "parent", active: true}],
      [
        "child-a",
        {uid: "child-a", role: "child", childId: "child-1", active: true},
      ],
      ["inactive", {uid: "inactive", role: "parent", active: false}],
      ["mismatched", {uid: "different-uid", role: "parent", active: true}],
      ["false-owner", {uid: "false-owner", role: "owner", active: true}],
    ];

    for (const [uid, data] of familyAMembers) {
      await setDoc(
        doc(db, "families", FAMILY_A, "members", uid),
        data
      );
    }
    await setDoc(
      doc(db, "families", FAMILY_B, "members", "owner-b"),
      {uid: "owner-b", role: "owner", active: true}
    );

    for (const collectionName of memberReadableCollections) {
      await setDoc(businessRef(db, collectionName), {
        seed: true,
        value: 1,
      });
      await setDoc(
        businessRef(db, collectionName, "document-b", FAMILY_B),
        {seed: true, value: 2}
      );
    }
    await setDoc(businessRef(db, "children"), {
      id: "document-1",
      name: "Enfant",
      avatar: "",
      photoBase64: "",
      points: 10,
      level: 1,
      badgeIds: [],
      createdAt: "2026-07-28T12:00:00.000Z",
      lastModifiedBy: "device-seed",
    });

    await setDoc(
      businessRef(db, "parent_profiles"),
      {id: "document-1", name: "Parent"}
    );
    await setDoc(
      businessRef(db, "requests", "request-1"),
      requestData("request-1")
    );
    await setDoc(
      businessRef(db, "join_requests", "join-1"),
      {status: "pending"}
    );
    await setDoc(
      businessRef(db, "fcm_tokens", "device-a"),
      fcmData("child-a", "device-a")
    );
    await setDoc(
      businessRef(db, "wallets", "child-1"),
      {childId: "child-1", balance: 10}
    );
    await setDoc(
      doc(
        db,
        "families",
        FAMILY_A,
        "wallets",
        "child-1",
        "operations",
        "operation-1"
      ),
      {childId: "child-1", amount: 10}
    );
  });
}

test.before(async () => {
  assert.equal(PROJECT_ID, "demo-sks-family");
  assert.ok(
    process.env.FIRESTORE_EMULATOR_HOST,
    "FIRESTORE_EMULATOR_HOST absent : le test refuse de contacter Firestore réel."
  );

  const rules = fs.readFileSync(
    path.join(__dirname, "..", "firestore.rules"),
    "utf8"
  );
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {rules},
  });
});

test.beforeEach(seedFirestore);

test.after(async () => {
  if (testEnv) await testEnv.cleanup();
});

test("family document is readable only by active coherent members", async () => {
  for (const uid of ["owner-a", "parent-a", "child-a"]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(familyRef(db)));
  }

  for (const uid of [
    "owner-b",
    "outsider",
    "inactive",
    "mismatched",
    "false-owner",
  ]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDoc(familyRef(db)));
  }
  await assertFails(
    getDoc(familyRef(testEnv.unauthenticatedContext().firestore()))
  );
});

test("all direct client writes to family documents are denied", async () => {
  const contexts = [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("owner-a"),
    testEnv.authenticatedContext("parent-a"),
    testEnv.authenticatedContext("child-a"),
    testEnv.authenticatedContext("owner-b"),
  ];

  for (const context of contexts) {
    const db = context.firestore();
    await assertFails(setDoc(familyRef(db, "new-family"), {ownerUid: "x"}));
    await assertFails(updateDoc(familyRef(db), {code: "HACKED"}));
    await assertFails(deleteDoc(familyRef(db)));
  }
});

for (const collectionName of memberReadableCollections) {
  test(`${collectionName}: reads require an active coherent family member`, async () => {
    for (const uid of ["owner-a", "parent-a", "child-a"]) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertSucceeds(getDoc(businessRef(db, collectionName)));
      await assertSucceeds(
        getDocs(familyCollectionRef(db, collectionName))
      );
    }

    for (const uid of [
      "owner-b",
      "outsider",
      "inactive",
      "mismatched",
      "false-owner",
    ]) {
      const db = testEnv.authenticatedContext(uid).firestore();
      await assertFails(getDoc(businessRef(db, collectionName)));
      await assertFails(
        getDocs(familyCollectionRef(db, collectionName))
      );
    }

    const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
    await assertFails(getDoc(businessRef(unauthenticatedDb, collectionName)));
    await assertFails(
      getDocs(familyCollectionRef(unauthenticatedDb, collectionName))
    );
  });

}

for (const collectionName of parentWritableCollections) {
  test(`${collectionName}: only parent and owner can write`, async () => {
    const parentDb = testEnv.authenticatedContext("parent-a").firestore();
    const ownerDb = testEnv.authenticatedContext("owner-a").firestore();

    await assertSucceeds(
      setDoc(businessRef(parentDb, collectionName, "parent-created"), {
        createdBy: "parent",
      })
    );
    await assertSucceeds(
      updateDoc(businessRef(parentDb, collectionName), {value: 2})
    );
    await assertSucceeds(
      deleteDoc(businessRef(parentDb, collectionName, "parent-created"))
    );
    await assertSucceeds(
      setDoc(businessRef(ownerDb, collectionName, "owner-created"), {
        createdBy: "owner",
      })
    );

    for (const context of [
      testEnv.unauthenticatedContext(),
      testEnv.authenticatedContext("child-a"),
      testEnv.authenticatedContext("owner-b"),
      testEnv.authenticatedContext("outsider"),
      testEnv.authenticatedContext("inactive"),
      testEnv.authenticatedContext("mismatched"),
      testEnv.authenticatedContext("false-owner"),
    ]) {
      const db = context.firestore();
      await assertFails(
        setDoc(businessRef(db, collectionName, "forbidden"), {
          forged: true,
        })
      );
      await assertFails(
        updateDoc(businessRef(db, collectionName), {forged: true})
      );
      await assertFails(deleteDoc(businessRef(db, collectionName)));
    }
  });
}

test("children: +505 balance compatibility is narrow and parent-only", async () => {
  const parentDb = testEnv.authenticatedContext("parent-a").firestore();
  await assertSucceeds(
    setDoc(businessRef(parentDb, "children", "new-child"), {
      id: "new-child",
      name: "Enfant",
      points: 0,
    })
  );
  await assertFails(
    setDoc(businessRef(parentDb, "children", "forged-child"), {
      id: "forged-child",
      name: "Enfant",
      points: 999,
    })
  );
  await assertSucceeds(
    updateDoc(businessRef(parentDb, "children"), {
      points: 9,
      lastModifiedBy: "legacy-device",
    })
  );
  await assertFails(
    updateDoc(businessRef(parentDb, "children"), {
      points: 999,
      name: "Altération",
      lastModifiedBy: "legacy-device",
    })
  );
  const childDb = testEnv.authenticatedContext("child-a").firestore();
  await assertFails(
    updateDoc(businessRef(childDb, "children"), {points: 8})
  );
});

test("history: +505 creates are strict and server actor fields cannot be forged", async () => {
  const parentDb = testEnv.authenticatedContext("parent-a").firestore();
  await assertSucceeds(
    setDoc(businessRef(parentDb, "history", "legacy-valid"), {
      id: "legacy-valid",
      childId: "child-1",
      points: 5,
      reason: "Ancienne action compatible",
      category: "Bonus",
      date: "2026-07-28T12:00:00.000Z",
      isBonus: true,
      proofPhotoBase64: null,
      actionBy: "Parent",
      deviceId: "legacy-device",
    })
  );
  await assertFails(
    setDoc(businessRef(parentDb, "history", "legacy-base64"), {
      id: "legacy-base64",
      childId: "child-1",
      points: 5,
      reason: "Photo interdite",
      category: "Bonus",
      date: "2026-07-28T12:00:00.000Z",
      isBonus: true,
      proofPhotoBase64: "data:image/jpeg;base64,AAAA",
      actionBy: "Parent",
      deviceId: "legacy-device",
    })
  );
  for (const uid of ["owner-a", "parent-a", "child-a", "outsider"]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(
      setDoc(businessRef(db, "history", `forged-${uid}`), {
        actorUid: "victim",
        actorDisplayName: "Faux parent",
        actorRole: "owner",
        points: 999,
      })
    );
    await assertFails(
      updateDoc(businessRef(db, "history"), {actorUid: uid})
    );
    await assertFails(deleteDoc(businessRef(db, "history")));
  }
});

test("parent_profiles is restricted to parents and the real owner", async () => {
  for (const uid of ["owner-a", "parent-a"]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertSucceeds(getDoc(businessRef(db, "parent_profiles")));
    await assertSucceeds(
      getDocs(familyCollectionRef(db, "parent_profiles"))
    );
    await assertSucceeds(
      setDoc(businessRef(db, "parent_profiles", `profile-${uid}`), {
        id: `profile-${uid}`,
        name: uid,
      })
    );
  }

  for (const uid of [
    "child-a",
    "owner-b",
    "outsider",
    "inactive",
    "mismatched",
    "false-owner",
  ]) {
    const db = testEnv.authenticatedContext(uid).firestore();
    await assertFails(getDoc(businessRef(db, "parent_profiles")));
    await assertFails(
      setDoc(businessRef(db, "parent_profiles", "forbidden"), {
        forged: true,
      })
    );
  }
  const unauthenticatedDb = testEnv.unauthenticatedContext().firestore();
  await assertFails(getDoc(businessRef(unauthenticatedDb, "parent_profiles")));
  await assertFails(
    setDoc(businessRef(unauthenticatedDb, "parent_profiles", "forbidden"), {
      forged: true,
    })
  );
});

test("requests allows only a child own pending create and parent management", async () => {
  const childDb = testEnv.authenticatedContext("child-a").firestore();
  const parentDb = testEnv.authenticatedContext("parent-a").firestore();
  await assertSucceeds(getDoc(businessRef(childDb, "requests", "request-1")));
  await assertFails(
    getDoc(businessRef(childDb, "requests", "request-other-child"))
  );

  await assertSucceeds(
    setDoc(
      businessRef(childDb, "requests", "request-child"),
      requestData("request-child")
    )
  );
  await assertFails(
    setDoc(
      businessRef(childDb, "requests", "request-other-child"),
      requestData("request-other-child", "child-2")
    )
  );
  await assertFails(
    setDoc(
      businessRef(childDb, "requests", "request-approved"),
      requestData("request-approved", "child-1", {status: "approved"})
    )
  );
  await assertFails(
    setDoc(
      businessRef(childDb, "requests", "request-polluted"),
      requestData("request-polluted", "child-1", {role: "owner"})
    )
  );
  await assertFails(
    updateDoc(businessRef(childDb, "requests", "request-1"), {
      text: "Modification enfant",
    })
  );
  await assertFails(
    deleteDoc(businessRef(childDb, "requests", "request-1"))
  );

  await assertSucceeds(
    setDoc(
      businessRef(parentDb, "requests", "request-parent"),
      requestData("request-parent")
    )
  );
  await assertSucceeds(
    updateDoc(
      businessRef(parentDb, "requests", "request-parent"),
      requestData("request-parent", "child-1", {text: "Corrigée"})
    )
  );
  await assertSucceeds(
    deleteDoc(businessRef(parentDb, "requests", "request-parent"))
  );

  for (const context of [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("owner-b"),
    testEnv.authenticatedContext("outsider"),
    testEnv.authenticatedContext("inactive"),
    testEnv.authenticatedContext("mismatched"),
  ]) {
    const db = context.firestore();
    await assertFails(getDoc(businessRef(db, "requests", "request-1")));
    await assertFails(
      setDoc(
        businessRef(db, "requests", "request-forbidden"),
        requestData("request-forbidden")
      )
    );
  }
});

test("FCM tokens require active membership and a coherent immutable UID", async () => {
  const childDb = testEnv.authenticatedContext("child-a").firestore();
  const deviceRef = businessRef(childDb, "fcm_tokens", "device-new");

  await assertFails(getDoc(businessRef(childDb, "fcm_tokens", "device-a")));
  await assertSucceeds(
    setDoc(deviceRef, fcmData("child-a", "device-new"))
  );
  await assertSucceeds(
    setDoc(deviceRef, fcmData("child-a", "device-new", "token-updated"))
  );
  await assertFails(
    setDoc(deviceRef, fcmData("owner-a", "device-new", "forged"))
  );
  await assertFails(
    setDoc(
      businessRef(childDb, "fcm_tokens", "different-path"),
      fcmData("child-a", "different-device")
    )
  );
  await assertSucceeds(deleteDoc(deviceRef));

  const forbiddenFcmContexts = [
    [testEnv.unauthenticatedContext(), "unauthenticated"],
    [testEnv.authenticatedContext("owner-b"), "owner-b"],
    [testEnv.authenticatedContext("outsider"), "outsider"],
    [testEnv.authenticatedContext("inactive"), "inactive"],
    [testEnv.authenticatedContext("mismatched"), "mismatched"],
  ];
  for (const [context, claimedUid] of forbiddenFcmContexts) {
    const db = context.firestore();
    await assertFails(
      setDoc(
        businessRef(db, "fcm_tokens", "forbidden-device"),
        fcmData(claimedUid, "forbidden-device")
      )
    );
  }
});

test("join requests stay parent-only while a member can read only itself", async () => {
  const ownerDb = testEnv.authenticatedContext("owner-a").firestore();
  await assertSucceeds(
    getDoc(businessRef(ownerDb, "join_requests", "join-1"))
  );
  await assertSucceeds(
    getDocs(familyCollectionRef(ownerDb, "join_requests"))
  );
  await assertSucceeds(
    getDoc(businessRef(ownerDb, "members", "parent-a"))
  );
  await assertSucceeds(getDocs(familyCollectionRef(ownerDb, "members")));
  const parentDb = testEnv.authenticatedContext("parent-a").firestore();
  await assertSucceeds(
    getDoc(businessRef(parentDb, "join_requests", "join-1"))
  );
  await assertSucceeds(
    getDocs(familyCollectionRef(parentDb, "join_requests"))
  );
  await assertSucceeds(
    getDoc(businessRef(parentDb, "members", "parent-a"))
  );
  await assertFails(
    getDoc(businessRef(parentDb, "members", "owner-a"))
  );
  await assertFails(getDocs(familyCollectionRef(parentDb, "members")));

  for (const context of [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("child-a"),
    testEnv.authenticatedContext("owner-b"),
    testEnv.authenticatedContext("outsider"),
    testEnv.authenticatedContext("inactive"),
    testEnv.authenticatedContext("mismatched"),
    testEnv.authenticatedContext("false-owner"),
  ]) {
    const db = context.firestore();
    await assertFails(
      getDoc(businessRef(db, "join_requests", "join-1"))
    );
    await assertFails(getDoc(businessRef(db, "members", "parent-a")));
  }

  for (const context of [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("owner-a"),
    testEnv.authenticatedContext("parent-a"),
    testEnv.authenticatedContext("child-a"),
  ]) {
    const db = context.firestore();
    await assertFails(
      setDoc(businessRef(db, "join_requests", "client-write"), {
        status: "pending",
      })
    );
    await assertFails(
      setDoc(businessRef(db, "members", "client-write"), {
        uid: "client-write",
        role: "owner",
        active: true,
      })
    );
  }
});

test("wallet data remains server-write-only and child-scoped", async () => {
  const childDb = testEnv.authenticatedContext("child-a").firestore();
  const parentDb = testEnv.authenticatedContext("parent-a").firestore();

  await assertSucceeds(
    getDoc(businessRef(childDb, "wallets", "child-1"))
  );
  await assertSucceeds(
    getDoc(businessRef(parentDb, "wallets", "child-1"))
  );
  await assertFails(
    getDoc(businessRef(childDb, "wallets", "child-2"))
  );
  await assertFails(
    updateDoc(businessRef(childDb, "wallets", "child-1"), {balance: 999})
  );
  await assertFails(
    updateDoc(businessRef(parentDb, "wallets", "child-1"), {balance: 999})
  );
});

test("all undeclared server collections remain denied to clients", async () => {
  const paths = [
    ["family_codes", "AAAAAA"],
    ["join_rate_limits", "owner-a"],
    ["legacy_family_migration_claims", FAMILY_A],
    ["_diagnostic_test", "test_safari"],
  ];

  for (const context of [
    testEnv.unauthenticatedContext(),
    testEnv.authenticatedContext("owner-a"),
  ]) {
    const db = context.firestore();
    for (const segments of paths) {
      const ref = doc(db, ...segments);
      await assertFails(getDoc(ref));
      await assertFails(setDoc(ref, {forged: true}));
    }
  }
});
