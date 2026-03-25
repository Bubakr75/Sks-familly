const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

// ===== HELPER : envoyer à toute la famille SAUF l'émetteur =====
async function sendToFamily(familyId, senderDeviceId, title, body, data) {
  const tokensSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) return;

  const tokens = [];
  tokensSnap.docs.forEach((doc) => {
    // Ne pas envoyer à l'appareil qui a fait l'action
    if (doc.id !== senderDeviceId) {
      const token = doc.data().token;
      if (token) tokens.push(token);
    }
  });

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: data || {},
    android: {
      notification: {
        channelId: "sks_family_channel",
        icon: "@mipmap/ic_launcher",
        sound: "default",
        priority: "high",
      },
    },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    response.responses.forEach((resp, idx) => {
      if (
        !resp.success &&
        resp.error &&
        (resp.error.code === "messaging/invalid-registration-token" ||
          resp.error.code === "messaging/registration-token-not-registered")
      ) {
        const badToken = tokens[idx];
        tokensSnap.docs.forEach((doc) => {
          if (doc.data().token === badToken) doc.ref.delete();
        });
      }
    });
    console.log("Sent to " + response.successCount + "/" + tokens.length + " devices");
  } catch (e) {
    console.error("FCM send error:", e);
  }
}

// Helper : récupérer le nom d'un enfant
async function getChildName(familyId, childId) {
  try {
    const snap = await db.collection("families").doc(familyId).collection("children").doc(childId).get();
    return snap.exists ? snap.data().name : "?";
  } catch (e) {
    return "?";
  }
}

// ===== 1. POINTS / BADGES (quand un enfant est modifié) =====
exports.onChildUpdate = functions.firestore
  .document("families/{familyId}/children/{childId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;
    const sender = after.lastModifiedBy || "";

    // Points changent
    if (before.points !== after.points) {
      const diff = after.points - before.points;
      const emoji = diff > 0 ? "⭐" : "⚠️";
      const sign = diff > 0 ? "+" : "";
      await sendToFamily(
        familyId,
        sender,
        emoji + " " + after.name,
        sign + diff + " points (total: " + after.points + ")",
        { type: "points", childId: context.params.childId }
      );
    }

    // Nouveau badge
    const oldBadges = before.badgeIds || [];
    const newBadges = after.badgeIds || [];
    if (newBadges.length > oldBadges.length) {
      await sendToFamily(
        familyId,
        sender,
        "🏆 Nouveau badge !",
        after.name + " a debloque un nouveau badge !",
        { type: "badge", childId: context.params.childId }
      );
    }
  });

// ===== 2. HISTORIQUE (bonus/malus ajouté) =====
exports.onHistoryCreated = functions.firestore
  .document("families/{familyId}/history/{entryId}")
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const familyId = context.params.familyId;
    const sender = data.deviceId || data.lastModifiedBy || "";

    // Notification note scolaire
    if (data.category === "school_note") {
      const childName = await getChildName(familyId, data.childId);
      await sendToFamily(
        familyId,
        sender,
        "📚 Note scolaire - " + childName,
        data.reason || "Note ajoutee",
        { type: "school_note", childId: data.childId || "" }
      );
      return;
    }

    // Notification temps d'écran
    if (data.category === "screen_time_bonus") {
      const childName = await getChildName(familyId, data.childId);
      await sendToFamily(
        familyId,
        sender,
        "📺 Temps d'ecran - " + childName,
        data.reason || "Modification",
        { type: "screen_time", childId: data.childId || "" }
      );
      return;
    }

    // Notification note samedi
    if (data.category === "saturday_rating") {
      const childName = await getChildName(familyId, data.childId);
      await sendToFamily(
        familyId,
        sender,
        "📋 Note samedi - " + childName,
        data.reason || "Note ajoutee",
        { type: "saturday_rating", childId: data.childId || "" }
      );
      return;
    }

    // Notification standard (bonus/malus)
    const childName = await getChildName(familyId, data.childId);
    const emoji = data.isBonus ? "✅" : "❌";
    const sign = data.isBonus ? "+" : "-";

    await sendToFamily(
      familyId,
      sender,
      emoji + " " + childName + " : " + sign + data.points + " pts",
      data.reason || "Points modifies",
      { type: "history", childId: data.childId || "" }
    );
  });

// ===== 3. PUNITIONS =====
exports.onPunishmentCreated = functions.firestore
  .document("families/{familyId}/punishments/{pId}")
  .onCreate(async (snap, context) => {
    const p = snap.data();
    const familyId = context.params.familyId;
    const sender = p.lastModifiedBy || "";
    const childName = await getChildName(familyId, p.childId);

    await sendToFamily(
      familyId,
      sender,
      "📝 Punition pour " + childName,
      p.totalLines + ' lignes : "' + p.text + '"',
      { type: "punishment", childId: p.childId || "" }
    );
  });

exports.onPunishmentUpdated = functions.firestore
  .document("families/{familyId}/punishments/{pId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;
    const sender = after.lastModifiedBy || "";

    if (before.completedLines !== after.completedLines) {
      const childName = await getChildName(familyId, after.childId);
      const pct = Math.round((after.completedLines / after.totalLines) * 100);

      if (after.completedLines >= after.totalLines) {
        await sendToFamily(
          familyId,
          sender,
          "🎉 Punition terminee !",
          childName + " a fini : " + after.totalLines + "/" + after.totalLines + " lignes",
          { type: "punishment_done", childId: after.childId || "" }
        );
      } else {
        await sendToFamily(
          familyId,
          sender,
          "📈 Progres - " + childName,
          after.completedLines + "/" + after.totalLines + " lignes (" + pct + "%)",
          { type: "punishment_progress", childId: after.childId || "" }
        );
      }
    }
  });

// ===== 4. IMMUNITES =====
exports.onImmunityCreated = functions.firestore
  .document("families/{familyId}/immunities/{imId}")
  .onCreate(async (snap, context) => {
    const im = snap.data();
    const familyId = context.params.familyId;
    const sender = im.lastModifiedBy || "";
    const childName = await getChildName(familyId, im.childId);

    await sendToFamily(
      familyId,
      sender,
      "🛡️ Immunite pour " + childName,
      im.lines + " ligne(s) : " + im.reason,
      { type: "immunity", childId: im.childId || "" }
    );
  });

// ===== 5. TRADES (VENTES) =====
exports.onTradeCreated = functions.firestore
  .document("families/{familyId}/trades/{tradeId}")
  .onCreate(async (snap, context) => {
    const trade = snap.data();
    const familyId = context.params.familyId;
    const sender = trade.lastModifiedBy || "";
    const seller = await getChildName(familyId, trade.fromChildId);
    const buyer = await getChildName(familyId, trade.toChildId);

    await sendToFamily(
      familyId,
      sender,
      "🏪 Nouvelle vente",
      seller + " propose " + trade.immunityLines + " ligne(s) a " + buyer + " - " + trade.serviceDescription,
      { type: "trade_new", tradeId: context.params.tradeId }
    );
  });

exports.onTradeUpdated = functions.firestore
  .document("families/{familyId}/trades/{tradeId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;
    const sender = after.lastModifiedBy || "";

    if (before.status === after.status) return;

    const seller = await getChildName(familyId, after.fromChildId);
    const buyer = await getChildName(familyId, after.toChildId);
    var title = "";
    var body = "";

    switch (after.status) {
      case "accepted":
        title = "✅ Vente acceptee";
        body = buyer + " a accepte la vente de " + seller;
        break;
      case "service_done":
        title = "⏳ Service termine";
        body = buyer + " dit avoir rendu le service - validation parent requise";
        break;
      case "completed":
        title = "🎉 Vente validee !";
        body = after.immunityLines + " ligne(s) transferee(s) de " + seller + " a " + buyer;
        break;
      case "cancelled":
        title = "❌ Vente annulee";
        body = "La vente entre " + seller + " et " + buyer + " a ete annulee";
        break;
      case "rejected":
        title = "🚫 Vente refusee";
        body = "La vente entre " + seller + " et " + buyer + " a ete refusee";
        break;
      default:
        return;
    }

    if (title) {
      await sendToFamily(familyId, sender, title, body, {
        type: "trade_update",
        tradeId: context.params.tradeId,
      });
    }
  });

// ===== 6. TRIBUNAL =====
exports.onTribunalCreated = functions.firestore
  .document("families/{familyId}/tribunal/{caseId}")
  .onCreate(async (snap, context) => {
    const tc = snap.data();
    const familyId = context.params.familyId;
    const sender = tc.lastModifiedBy || "";

    await sendToFamily(
      familyId,
      sender,
      "⚖️ Nouvelle affaire",
      tc.title || "Une plainte a ete deposee",
      { type: "tribunal_new", caseId: context.params.caseId }
    );
  });

exports.onTribunalUpdated = functions.firestore
  .document("families/{familyId}/tribunal/{caseId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;
    const sender = after.lastModifiedBy || "";

    if (before.status === after.status) return;

    var title = "⚖️ Tribunal";
    switch (after.status) {
      case "scheduled":
        title = "📅 Audience programmee";
        break;
      case "inProgress":
        title = "🔴 Audience en cours";
        break;
      case "deliberation":
        title = "🤔 Deliberation en cours";
        break;
      case "closed":
        title = "✅ Affaire close";
        break;
    }

    await sendToFamily(familyId, sender, title, after.title || "", {
      type: "tribunal_update",
      caseId: context.params.caseId,
    });
  });
