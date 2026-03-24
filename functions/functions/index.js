const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

async function sendToFamily(familyId, title, body, data) {
  const tokensSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) return;

  const tokens = tokensSnap.docs.map((doc) => doc.data().token).filter(Boolean);
  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: data || {},
    tokens: tokens,
  };

  try {
    const response = await messaging.sendEachForMulticast(message);
    response.responses.forEach((resp, idx) => {
      if (!resp.success && resp.error &&
          (resp.error.code === "messaging/invalid-registration-token" ||
           resp.error.code === "messaging/registration-token-not-registered")) {
        const badToken = tokens[idx];
        tokensSnap.docs.forEach((doc) => {
          if (doc.data().token === badToken) doc.ref.delete();
        });
      }
    });
  } catch (e) {
    console.error("FCM send error:", e);
  }
}

exports.onTradeCreated = functions.firestore
  .document("families/{familyId}/trades/{tradeId}")
  .onCreate(async (snap, context) => {
    const trade = snap.data();
    const familyId = context.params.familyId;

    const sellerSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(trade.fromChildId).get();
    const buyerSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(trade.toChildId).get();

    const seller = sellerSnap.exists ? sellerSnap.data().name : "?";
    const buyer = buyerSnap.exists ? buyerSnap.data().name : "?";

    await sendToFamily(familyId,
      "Nouvelle vente",
      seller + " propose " + trade.immunityLines + " ligne(s) a " + buyer,
      { type: "trade", tradeId: context.params.tradeId }
    );
  });

exports.onTradeUpdated = functions.firestore
  .document("families/{familyId}/trades/{tradeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;

    if (before.status === after.status) return;

    const sellerSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(after.fromChildId).get();
    const buyerSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(after.toChildId).get();
    const seller = sellerSnap.exists ? sellerSnap.data().name : "?";
    const buyer = buyerSnap.exists ? buyerSnap.data().name : "?";

    var title = "";
    var body = "";

    if (after.status === "accepted") {
      title = "Vente acceptee";
      body = buyer + " a accepte la vente de " + seller;
    } else if (after.status === "service_done") {
      title = "Service rendu";
      body = buyer + " dit avoir rendu le service - validation parent requise";
    } else if (after.status === "completed") {
      title = "Vente validee";
      body = seller + " vers " + buyer + " : " + after.immunityLines + " ligne(s) transferee(s)";
    } else if (after.status === "rejected") {
      title = "Vente refusee";
      body = "La vente entre " + seller + " et " + buyer + " a ete refusee";
    } else if (after.status === "cancelled") {
      title = "Vente annulee";
      body = "La vente entre " + seller + " et " + buyer + " a ete annulee";
    }

    if (title) {
      await sendToFamily(familyId, title, body,
        { type: "trade", tradeId: context.params.tradeId }
      );
    }
  });

exports.onHistoryCreated = functions.firestore
  .document("families/{familyId}/history/{entryId}")
  .onCreate(async (snap, context) => {
    const entry = snap.data();
    const familyId = context.params.familyId;

    const childSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(entry.childId).get();
    const childName = childSnap.exists ? childSnap.data().name : "?";

    var sign = entry.isBonus ? "+" : "-";

    await sendToFamily(familyId,
      childName + " : " + sign + entry.points + " pts",
      entry.reason || "Points modifies",
      { type: "history", childId: entry.childId }
    );
  });

exports.onPunishmentCreated = functions.firestore
  .document("families/{familyId}/punishments/{pId}")
  .onCreate(async (snap, context) => {
    const p = snap.data();
    const familyId = context.params.familyId;

    const childSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(p.childId).get();
    const childName = childSnap.exists ? childSnap.data().name : "?";

    await sendToFamily(familyId,
      "Punition pour " + childName,
      p.totalLines + " lignes : " + p.text,
      { type: "punishment", childId: p.childId }
    );
  });

exports.onImmunityCreated = functions.firestore
  .document("families/{familyId}/immunities/{imId}")
  .onCreate(async (snap, context) => {
    const im = snap.data();
    const familyId = context.params.familyId;

    const childSnap = await db.collection("families").doc(familyId)
      .collection("children").doc(im.childId).get();
    const childName = childSnap.exists ? childSnap.data().name : "?";

    await sendToFamily(familyId,
      "Immunite pour " + childName,
      im.lines + " ligne(s) : " + im.reason,
      { type: "immunity", childId: im.childId }
    );
  });

exports.onTribunalCreated = functions.firestore
  .document("families/{familyId}/tribunal/{caseId}")
  .onCreate(async (snap, context) => {
    const tc = snap.data();
    const familyId = context.params.familyId;

    await sendToFamily(familyId,
      "Nouvelle affaire au tribunal",
      tc.title || "Une plainte a ete deposee",
      { type: "tribunal", caseId: context.params.caseId }
    );
  });
