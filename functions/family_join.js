"use strict";

const {
  requireAuthenticatedUid,
  isAuthenticatedFamilyOwner,
  applyFamilyOwnerRepair,
} = require("./family_owner_authorization");

const JOIN_WINDOW_MS = 15 * 60 * 1000;
const JOIN_MAX_ATTEMPTS = 10;
const JOIN_BLOCK_MS = 30 * 60 * 1000;

function normalizeFamilyCode(value) {
  if (typeof value !== "string") {
    throw new Error("INVALID_FAMILY_CODE");
  }

  const code = value.trim().toUpperCase();

  if (
    code.length < 4 ||
    code.length > 32 ||
    /[\u0000-\u001f/]/.test(code)
  ) {
    throw new Error("INVALID_FAMILY_CODE");
  }

  return code;
}

function normalizeJoinRole(value) {
  if (value !== "parent" && value !== "child") {
    throw new Error("INVALID_JOIN_ROLE");
  }

  return value;
}

function cleanText(value, maxLength, required) {
  if (value == null) {
    if (required) throw new Error("MISSING_TEXT");
    return "";
  }

  if (typeof value !== "string") {
    throw new Error("INVALID_TEXT");
  }

  const text = value.trim();

  if ((required && text.length === 0) || text.length > maxLength) {
    throw new Error("INVALID_TEXT");
  }

  return text;
}

function cleanDocumentId(value, fieldName) {
  const id = cleanText(value, 128, true);

  if (id.includes("/") || id === "." || id === "..") {
    throw new Error("INVALID_" + fieldName.toUpperCase());
  }

  return id;
}

function buildJoinRequestData({
  requesterUid,
  requestedRole,
  requestedChildName,
  deviceId,
  deviceName,
  createdAt,
}) {
  return {
    requesterUid,
    requestedRole,
    requestedChildName:
      requestedRole === "child" ? requestedChildName : null,
    deviceId,
    deviceName,
    status: "sent",
    createdAt,
    updatedAt: createdAt,
    reviewedBy: null,
    reviewedAt: null,
    selectedChildId: null,
    readBy: [],
  };
}

function buildApprovedMemberData({
  requesterUid,
  requestedRole,
  childId,
  approvedBy,
  createdAt,
}) {
  return {
    uid: requesterUid,
    role: requestedRole,
    childId: requestedRole === "child" ? childId : null,
    active: true,
    createdAt,
    approvedBy,
    approvedAt: createdAt,
  };
}

function createFamilyJoinFunctions({ functions, admin, db }) {
  const HttpsError = functions.https.HttpsError;
  const fieldValue = admin.firestore.FieldValue;

  function requireAuth(context) {
    if (!context.auth || !context.auth.uid) {
      throw new HttpsError(
        "unauthenticated",
        "Une authentification Firebase est requise."
      );
    }

    return context.auth.uid;
  }

  function toHttpsError(error) {
    if (error instanceof HttpsError) return error;

    switch (error && error.message) {
      case "INVALID_FAMILY_CODE":
        return new HttpsError("invalid-argument", "Code famille invalide.");
      case "INVALID_JOIN_ROLE":
        return new HttpsError("invalid-argument", "Role demande invalide.");
      case "MISSING_TEXT":
      case "INVALID_TEXT":
        return new HttpsError(
          "invalid-argument",
          "Une information obligatoire est invalide."
        );
      default:
        if (
          error &&
          typeof error.message === "string" &&
          error.message.startsWith("INVALID_")
        ) {
          return new HttpsError(
            "invalid-argument",
            "Un identifiant transmis est invalide."
          );
        }

        console.error("Family join callable error:", error);
        return new HttpsError("internal", "Une erreur interne est survenue.");
    }
  }

  async function enforceJoinRateLimit(uid) {
    const ref = db.collection("join_rate_limits").doc(uid);
    const now = Date.now();

    const allowed = await db.runTransaction(async (transaction) => {
      const snapshot = await transaction.get(ref);
      const previous = snapshot.exists ? snapshot.data() : {};

      if (
        Number.isFinite(previous.blockedUntilMillis) &&
        previous.blockedUntilMillis > now
      ) {
        return false;
      }

      const sameWindow =
        Number.isFinite(previous.windowStartedAtMillis) &&
        now - previous.windowStartedAtMillis < JOIN_WINDOW_MS;

      const count = sameWindow ? Number(previous.count || 0) : 0;
      const windowStartedAtMillis = sameWindow
        ? previous.windowStartedAtMillis
        : now;

      if (count >= JOIN_MAX_ATTEMPTS) {
        transaction.set(
          ref,
          {
            count,
            windowStartedAtMillis,
            blockedUntilMillis: now + JOIN_BLOCK_MS,
            updatedAt: fieldValue.serverTimestamp(),
          },
          { merge: true }
        );
        return false;
      }

      transaction.set(
        ref,
        {
          count: count + 1,
          windowStartedAtMillis,
          blockedUntilMillis: null,
          updatedAt: fieldValue.serverTimestamp(),
        },
        { merge: true }
      );

      return true;
    });

    if (!allowed) {
      throw new HttpsError(
        "resource-exhausted",
        "Trop de tentatives. Reessayez plus tard."
      );
    }
  }

  async function findFamilyByCode(code) {
    const snapshot = await db
      .collection("families")
      .where("code", "==", code)
      .limit(2)
      .get();

    if (snapshot.empty) {
      throw new HttpsError(
        "not-found",
        "Code famille introuvable ou indisponible."
      );
    }

    if (snapshot.size > 1) {
      console.error("Duplicate family code detected:", code);
      throw new HttpsError(
        "failed-precondition",
        "Ce code famille ne peut pas etre utilise actuellement."
      );
    }

    return snapshot.docs[0];
  }

  const requestFamilyJoin = functions.https.onCall(
    async (data, context) => {
      try {
        const requesterUid = requireAuth(context);
        const code = normalizeFamilyCode(data && data.code);
        const requestedRole = normalizeJoinRole(
          data && data.requestedRole
        );
        const deviceId = cleanDocumentId(
          data && data.deviceId,
          "device_id"
        );
        const deviceName = cleanText(
          data && data.deviceName,
          80,
          false
        );
        const requestedChildName =
          requestedRole === "child"
            ? cleanText(data && data.requestedChildName, 80, true)
            : "";

        await enforceJoinRateLimit(requesterUid);

        const familySnapshot = await findFamilyByCode(code);
        const familyRef = familySnapshot.ref;
        const familyId = familyRef.id;
        const memberRef = familyRef
          .collection("members")
          .doc(requesterUid);
        const requestRef = familyRef
          .collection("join_requests")
          .doc(requesterUid);

        const result = await db.runTransaction(async (transaction) => {
          const currentFamily = await transaction.get(familyRef);
          const currentMember = await transaction.get(memberRef);
          const existingRequest = await transaction.get(requestRef);

          if (!currentFamily.exists) {
            throw new HttpsError(
              "not-found",
              "Cette famille n'existe plus."
            );
          }

          const familyData = currentFamily.data();

          if (
            !familyData.ownerUid ||
            familyData.schemaVersion !== 2
          ) {
            throw new HttpsError(
              "failed-precondition",
              "Cette famille doit d'abord etre migree par son parent."
            );
          }

          if (
            currentMember.exists &&
            currentMember.data().active === true
          ) {
            throw new HttpsError(
              "already-exists",
              "Cet appareil appartient deja a cette famille."
            );
          }

          if (
            existingRequest.exists &&
            ["pending", "sent", "received"].includes(
              existingRequest.data().status
            )
          ) {
            return {
              alreadyPending: true,
              requestedRole: existingRequest.data().requestedRole,
            };
          }

          const timestamp = fieldValue.serverTimestamp();

          transaction.set(
            requestRef,
            buildJoinRequestData({
              requesterUid,
              requestedRole,
              requestedChildName,
              deviceId,
              deviceName,
              createdAt: timestamp,
            })
          );

          return { alreadyPending: false, requestedRole };
        });

        return {
          familyId,
          requestId: requesterUid,
          status: "sent",
          alreadyPending: result.alreadyPending,
          requestedRole: result.requestedRole,
        };
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  const getFamilyJoinStatus = functions.https.onCall(
    async (data, context) => {
      try {
        const requesterUid = requireAuth(context);
        const familyId = cleanDocumentId(
          data && data.familyId,
          "family_id"
        );

        const familyRef = db.collection("families").doc(familyId);
        const requestRef = familyRef
          .collection("join_requests")
          .doc(requesterUid);
        const memberRef = familyRef
          .collection("members")
          .doc(requesterUid);

        const [requestSnapshot, memberSnapshot] = await Promise.all([
          requestRef.get(),
          memberRef.get(),
        ]);

        if (!requestSnapshot.exists) {
          throw new HttpsError(
            "not-found",
            "Demande de connexion introuvable."
          );
        }

        const requestData = requestSnapshot.data();
        const memberData = memberSnapshot.exists
          ? memberSnapshot.data()
          : null;

        return {
          familyId,
          status: requestData.status || "pending",
          role:
            memberData && memberData.active === true
              ? memberData.role || null
              : null,
          childId:
            memberData && memberData.active === true
              ? memberData.childId || null
              : null,
        };
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  const approveFamilyJoin = functions.https.onCall(
    async (data, context) => {
      try {
        const reviewerUid = requireAuthenticatedUid(
          context,
          HttpsError
        );
        const familyId = cleanDocumentId(
          data && data.familyId,
          "family_id"
        );
        const requesterUid = cleanDocumentId(
          data && data.requesterUid,
          "requester_uid"
        );
        const selectedChildId =
          data && data.childId != null
            ? cleanDocumentId(data.childId, "child_id")
            : null;

        if (reviewerUid === requesterUid) {
          throw new HttpsError(
            "permission-denied",
            "Vous ne pouvez pas approuver votre propre demande."
          );
        }

        const familyRef = db.collection("families").doc(familyId);
        const reviewerRef = familyRef
          .collection("members")
          .doc(reviewerUid);
        const requestRef = familyRef
          .collection("join_requests")
          .doc(requesterUid);
        const newMemberRef = familyRef
          .collection("members")
          .doc(requesterUid);

        const approval = await db.runTransaction(
          async (transaction) => {
            const familySnapshot = await transaction.get(familyRef);
            const reviewerSnapshot = await transaction.get(reviewerRef);
            const requestSnapshot = await transaction.get(requestRef);
            const memberSnapshot = await transaction.get(newMemberRef);

            if (!familySnapshot.exists || !requestSnapshot.exists) {
              throw new HttpsError(
                "not-found",
                "Famille ou demande introuvable."
              );
            }

            const family = familySnapshot.data();
            const reviewer = reviewerSnapshot.exists
              ? reviewerSnapshot.data()
              : null;
            const request = requestSnapshot.data();

            if (
              request.requesterUid !== requesterUid
            ) {
              throw new HttpsError(
                "failed-precondition",
                "Cette demande ne peut plus etre approuvee."
              );
            }

            const requestedRole = normalizeJoinRole(
              request.requestedRole
            );
            const pendingRequest =
              ["pending", "sent", "received"].includes(request.status);
            const alreadyApproved =
              ["approved", "accepted"].includes(request.status) &&
              memberSnapshot.exists &&
              memberSnapshot.data().active === true &&
              memberSnapshot.data().uid === requesterUid &&
              memberSnapshot.data().role === requestedRole;

            if (!pendingRequest && !alreadyApproved) {
              throw new HttpsError(
                "failed-precondition",
                "Cette demande ne peut plus etre approuvee."
              );
            }

            let ownerAuthorization = null;

            if (requestedRole === "parent") {
              ownerAuthorization = isAuthenticatedFamilyOwner({
                context,
                familySnapshot,
                memberSnapshot: reviewerSnapshot,
                HttpsError,
                allowRepair: true,
              });
            } else {
              const reviewerIsParent =
                reviewer &&
                reviewer.uid === reviewerUid &&
                reviewer.active === true &&
                (
                  reviewer.role === "parent" ||
                  (
                    reviewer.role === "owner" &&
                    family.ownerUid === reviewerUid
                  )
                );

              if (!reviewerIsParent) {
                throw new HttpsError(
                  "permission-denied",
                  "Seul un parent autorise peut traiter cette demande."
                );
              }
            }

            if (alreadyApproved) {
              if (ownerAuthorization && ownerAuthorization.repair) {
                const repairTimestamp = fieldValue.serverTimestamp();
                applyFamilyOwnerRepair({
                  transaction,
                  memberRef: reviewerRef,
                  authorization: ownerAuthorization,
                  timestamp: repairTimestamp,
                });
                console.warn("Family owner membership repaired", {
                  reason: ownerAuthorization.diagnosticCode,
                  familyFormat: ownerAuthorization.familyFormat,
                });
              }

              return {
                role: requestedRole,
                childId:
                  requestedRole === "child"
                    ? memberSnapshot.data().childId || null
                    : null,
              };
            }

            let childSnapshot = null;

            if (requestedRole === "child") {
              if (!selectedChildId) {
                throw new HttpsError(
                  "invalid-argument",
                  "Le profil enfant doit etre choisi par le parent."
                );
              }

              childSnapshot = await transaction.get(
                familyRef.collection("children").doc(selectedChildId)
              );

              if (!childSnapshot.exists) {
                throw new HttpsError(
                  "not-found",
                  "Profil enfant introuvable."
                );
              }
            }

            const timestamp = fieldValue.serverTimestamp();

            if (ownerAuthorization && ownerAuthorization.repair) {
              applyFamilyOwnerRepair({
                transaction,
                memberRef: reviewerRef,
                authorization: ownerAuthorization,
                timestamp,
              });
              console.warn("Family owner membership repaired", {
                reason: ownerAuthorization.diagnosticCode,
                familyFormat: ownerAuthorization.familyFormat,
              });
            }

            const wasActive =
              memberSnapshot.exists &&
              memberSnapshot.data().active === true;

            transaction.set(
              newMemberRef,
              buildApprovedMemberData({
                requesterUid,
                requestedRole,
                childId: selectedChildId,
                approvedBy: reviewerUid,
                createdAt: timestamp,
              })
            );

            transaction.update(requestRef, {
              status: "accepted",
              selectedChildId:
                requestedRole === "child" ? selectedChildId : null,
              reviewedBy: reviewerUid,
              reviewedAt: timestamp,
              updatedAt: timestamp,
            });

            if (!wasActive) {
              transaction.update(familyRef, {
                memberCount: fieldValue.increment(1),
              });
            }

            return {
              role: requestedRole,
              childId:
                requestedRole === "child" ? selectedChildId : null,
            };
          }
        );

        return {
          familyId,
          requesterUid,
          status: "accepted",
          role: approval.role,
          childId: approval.childId,
        };
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  const rejectFamilyJoin = functions.https.onCall(
    async (data, context) => {
      try {
        const reviewerUid = requireAuthenticatedUid(
          context,
          HttpsError
        );
        const familyId = cleanDocumentId(
          data && data.familyId,
          "family_id"
        );
        const requesterUid = cleanDocumentId(
          data && data.requesterUid,
          "requester_uid"
        );

        if (reviewerUid === requesterUid) {
          throw new HttpsError(
            "permission-denied",
            "Vous ne pouvez pas refuser votre propre demande."
          );
        }

        const familyRef = db.collection("families").doc(familyId);
        const reviewerRef = familyRef
          .collection("members")
          .doc(reviewerUid);
        const requestRef = familyRef
          .collection("join_requests")
          .doc(requesterUid);

        await db.runTransaction(async (transaction) => {
          const familySnapshot = await transaction.get(familyRef);
          const reviewerSnapshot = await transaction.get(reviewerRef);
          const requestSnapshot = await transaction.get(requestRef);

          if (!familySnapshot.exists || !requestSnapshot.exists) {
            throw new HttpsError(
              "not-found",
              "Famille ou demande introuvable."
            );
          }

          const family = familySnapshot.data();
          const reviewer = reviewerSnapshot.exists
            ? reviewerSnapshot.data()
            : null;
          const request = requestSnapshot.data();

          let ownerAuthorization = null;

          if (request.requestedRole === "parent") {
            ownerAuthorization = isAuthenticatedFamilyOwner({
              context,
              familySnapshot,
              memberSnapshot: reviewerSnapshot,
              HttpsError,
              allowRepair: true,
            });
          } else {
            const reviewerIsParent =
              reviewer &&
              reviewer.uid === reviewerUid &&
              reviewer.active === true &&
              (
                reviewer.role === "parent" ||
                (
                  reviewer.role === "owner" &&
                  family.ownerUid === reviewerUid
                )
              );

            if (!reviewerIsParent) {
              throw new HttpsError(
                "permission-denied",
                "Seul un parent autorise peut traiter cette demande."
              );
            }
          }

          if (["rejected", "refused"].includes(request.status)) {
            if (ownerAuthorization && ownerAuthorization.repair) {
              const repairTimestamp = fieldValue.serverTimestamp();
              applyFamilyOwnerRepair({
                transaction,
                memberRef: reviewerRef,
                authorization: ownerAuthorization,
                timestamp: repairTimestamp,
              });
            }
            return;
          }

          if (!["pending", "sent", "received"].includes(request.status)) {
            throw new HttpsError(
              "failed-precondition",
              "Cette demande ne peut plus etre refusee."
            );
          }

          const timestamp = fieldValue.serverTimestamp();

          if (ownerAuthorization && ownerAuthorization.repair) {
            applyFamilyOwnerRepair({
              transaction,
              memberRef: reviewerRef,
              authorization: ownerAuthorization,
              timestamp,
            });
            console.warn("Family owner membership repaired", {
              reason: ownerAuthorization.diagnosticCode,
              familyFormat: ownerAuthorization.familyFormat,
            });
          }

          transaction.update(requestRef, {
            status: "refused",
            reviewedBy: reviewerUid,
            reviewedAt: timestamp,
            updatedAt: timestamp,
          });
        });

        return {
          familyId,
          requesterUid,
          status: "refused",
        };
      } catch (error) {
        throw toHttpsError(error);
      }
    }
  );

  return {
    requestFamilyJoin,
    getFamilyJoinStatus,
    approveFamilyJoin,
    rejectFamilyJoin,
  };
}

module.exports = {
  normalizeFamilyCode,
  normalizeJoinRole,
  cleanText,
  cleanDocumentId,
  buildJoinRequestData,
  buildApprovedMemberData,
  createFamilyJoinFunctions,
};
