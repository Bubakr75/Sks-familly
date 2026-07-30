const functions = require("firebase-functions");
const admin = require("firebase-admin");
admin.initializeApp();

const db = admin.firestore();

const { createFamilyJoinFunctions } = require("./family_join");
const familyJoinFunctions = createFamilyJoinFunctions({
  functions,
  admin,
  db,
});

exports.requestFamilyJoin = familyJoinFunctions.requestFamilyJoin;
exports.getFamilyJoinStatus = familyJoinFunctions.getFamilyJoinStatus;
exports.approveFamilyJoin = familyJoinFunctions.approveFamilyJoin;
exports.rejectFamilyJoin = familyJoinFunctions.rejectFamilyJoin;

const {createFamilyInboxFunctions} = require("./family_inbox");
const familyInboxFunctions =
  createFamilyInboxFunctions({functions, admin, db});
exports.markFamilyInboxRead = familyInboxFunctions.markFamilyInboxRead;

const {
  createFamilyManagementFunctions,
} = require("./family_management");

const familyManagementFunctions = createFamilyManagementFunctions({
  functions,
  admin,
  db,
});

exports.createFamily = familyManagementFunctions.createFamily;
exports.changeFamilyCode = familyManagementFunctions.changeFamilyCode;

const {createWalletFunctions} = require("./wallet");
const walletFunctions = createWalletFunctions({
  functions,
  admin,
  db,
});

exports.adjustWallet = walletFunctions.adjustWallet;

const {
  createSecureChildOperationFunctions,
} = require("./secure_child_operations");
const secureChildOperationFunctions =
  createSecureChildOperationFunctions({functions, admin, db});
exports.performFamilyOperation =
  secureChildOperationFunctions.performFamilyOperation;

const {
  createLegacyFamilyMigrationFunctions,
} = require("./legacy_family_migration");

const legacyFamilyMigrationFunctions =
  createLegacyFamilyMigrationFunctions({
    functions,
    admin,
    db,
  });

exports.migrateLegacyFamily =
  legacyFamilyMigrationFunctions.migrateLegacyFamily;

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
    if (doc.id !== senderDeviceId) {
      const token = doc.data().token;
      if (token) tokens.push(token);
    }
  });

  if (tokens.length === 0) return;

  const message = {
    notification: { title, body },
    data: Object.assign({ sender: senderDeviceId }, data || {}),
    android: {
      notification: {
        channelId: "sks_family_channel",
        icon: "@mipmap/ic_launcher",
        sound: "default",
        priority: "high",
      },
    },
    webpush: {
      headers: { Urgency: "high" },
      notification: {
        title: title,
        body: body,
        icon: "/icons/Icon-192.png",
        badge: "/icons/Icon-192.png",
        requireInteraction: true,
      },
      fcmOptions: { link: "https://sks-familly-3f205.web.app" },
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

// ===== HELPER : envoyer SILENCIEUSEMENT (data-only, pas de bannière) =====
// La notif arrive dans l'app sans popup — juste mise à jour du badge cloche.
async function sendToFamilySilent(familyId, senderDeviceId, type, data) {
  const tokensSnap = await db
    .collection("families")
    .doc(familyId)
    .collection("fcm_tokens")
    .get();

  if (tokensSnap.empty) return;

  const tokens = [];
  tokensSnap.docs.forEach((doc) => {
    if (doc.id !== senderDeviceId) {
      const token = doc.data().token;
      if (token) tokens.push(token);
    }
  });

  if (tokens.length === 0) return;

  // Message data-only : PAS de clé "notification" = pas de bannière système
  const message = {
    data: Object.assign(
      { sender: senderDeviceId, silent: "true", type: type },
      data || {}
    ),
    android: { priority: "normal" },
    webpush: { headers: { Urgency: "low" } },
    tokens: tokens,
  };

  try {
    const response = await admin.messaging().sendEachForMulticast(message);
    console.log("[SILENT] Sent to " + response.successCount + "/" + tokens.length + " devices");
  } catch (e) {
    console.error("FCM silent send error:", e);
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

// ===== 1. BADGES (quand un enfant gagne un nouveau badge) =====
exports.onChildUpdate = functions.firestore
  .document("families/{familyId}/children/{childId}")
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();
    const familyId = context.params.familyId;
    const sender = after.lastModifiedBy || "";

    // Nouveau badge uniquement (PAS de notif pour les points - volontaire)
    const oldBadges = before.badgeIds || [];
    const newBadges = after.badgeIds || [];
    if (newBadges.length > oldBadges.length) {
      await sendToFamilySilent(
        familyId,
        sender,
        "badge",
        { childId: context.params.childId, title: "🏆 Nouveau badge", body: after.name + " a débloqué un badge !" }
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

    // Notification note scolaire — SILENCIEUSE
    if (data.category === "school_note") {
      const childName = await getChildName(familyId, data.childId);
      await sendToFamilySilent(
        familyId,
        sender,
        "school_note",
        { childId: data.childId || "", title: "📚 Note scolaire", body: childName + " : " + (data.reason || "") }
      );
      return;
    }

    // PAS de notification pour le temps d'écran ni la note samedi
    if (data.category === "screen_time_bonus" || data.category === "saturday_rating") {
      return;
    }

    // Notification standard (bonus/malus) — SILENCIEUSE
    const childName = await getChildName(familyId, data.childId);
    const emoji = data.isBonus ? "✅" : "⚠️";
    const sign = data.isBonus ? "+" : "-";

    await sendToFamilySilent(
      familyId,
      sender,
      "history",
      { childId: data.childId || "", title: emoji + " " + childName + " : " + sign + data.points + " pts", body: data.reason || "" }
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

    await sendToFamilySilent(
      familyId,
      sender,
      "punishment",
      { childId: p.childId || "", title: "📝 Punition", body: childName + " : " + p.totalLines + " lignes" }
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
        await sendToFamilySilent(
          familyId,
          sender,
          "punishment_done",
          { childId: after.childId || "", title: "🎉 Punition terminée", body: childName + " a fini !" }
        );
      } else {
        await sendToFamilySilent(
          familyId,
          sender,
          "punishment_progress",
          { childId: after.childId || "", title: "📈 Progrès " + childName, body: after.completedLines + "/" + after.totalLines + " (" + pct + "%)" }
        );
      }
    }
  });

// ===== 4. IMMUNITÉS =====
exports.onImmunityCreated = functions.firestore
  .document("families/{familyId}/immunities/{imId}")
  .onCreate(async (snap, context) => {
    const im = snap.data();
    const familyId = context.params.familyId;
    const sender = im.lastModifiedBy || "";
    const childName = await getChildName(familyId, im.childId);

    await sendToFamilySilent(
      familyId,
      sender,
      "immunity",
      { childId: im.childId || "", title: "🛡️ Immunité", body: childName + " : " + im.lines + " ligne(s)" }
    );
  });

// ===== 5. ÉCHANGES (VENTES) =====
exports.onTradeCreated = functions.firestore
  .document("families/{familyId}/trades/{tradeId}")
  .onCreate(async (snap, context) => {
    const trade = snap.data();
    const familyId = context.params.familyId;
    const sender = trade.lastModifiedBy || "";
    const seller = await getChildName(familyId, trade.fromChildId);
    const buyer = await getChildName(familyId, trade.toChildId);

    await sendToFamilySilent(
      familyId,
      sender,
      "trade_new",
      { tradeId: context.params.tradeId, title: "🏪 Nouvelle vente", body: seller + " → " + buyer }
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
        title = "✅ Vente acceptée";
        body = buyer + " a accepté la vente de " + seller;
        break;
      case "service_done":
        title = "⏳ Service terminé";
        body = buyer + " dit avoir rendu le service - validation parent requise";
        break;
      case "completed":
        title = "🎉 Vente validée !";
        body = after.immunityLines + " ligne(s) transférée(s) de " + seller + " à " + buyer;
        break;
      case "cancelled":
        title = "❌ Vente annulée";
        body = "La vente entre " + seller + " et " + buyer + " a été annulée";
        break;
      case "rejected":
        title = "🚫 Vente refusée";
        body = "La vente entre " + seller + " et " + buyer + " a été refusée";
        break;
      default:
        return;
    }

    if (title) {
      await sendToFamilySilent(familyId, sender, "trade_update", {
        tradeId: context.params.tradeId,
        title: title,
        body: body,
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
      tc.title || "Une plainte a été déposée",
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
        title = "📅 Audience programmée";
        break;
      case "inProgress":
        title = "🔴 Audience en cours";
        break;
      case "deliberation":
        title = "🤔 Délibération en cours";
        break;
      case "closed":
        title = "✅ Affaire close";
        break;
    }

    // Le VERDICT (closed) reste en push visible, le reste est silencieux
    if (after.status === "closed") {
      await sendToFamily(familyId, sender, title, after.title || "", {
        type: "tribunal_update",
        caseId: context.params.caseId,
      });
    } else {
      await sendToFamilySilent(familyId, sender, "tribunal_update", {
        caseId: context.params.caseId,
        title: title,
        body: after.title || "",
      });
    }
  });

// ===== 7. DEMANDES EN ATTENTE (validation parentale) =====
exports.onRequestCreated = functions.firestore
  .document("families/{familyId}/requests/{reqId}")
  .onCreate(async (snap, context) => {
    const r = snap.data();
    const familyId = context.params.familyId;
    const sender = r.lastModifiedBy || "";

    // 🤫 Pas de notification push pour les tâches checklist (évite le spam)
    // Le parent verra la demande dans le badge cloche sans recevoir de notif
    if (r.type === "chore_checklist") {
      console.log("Chore checklist request (no push notification)");
      return;
    }

    var title = "🔔 Nouvelle demande";
    var body = r.text || "Une demande attend votre validation";
    var notifType = "request";

    switch (r.type) {
      case "punishment":
        title = "📝 Demande de punition";
        body = (r.requestedBy || "Un enfant") + " propose " + r.amount + " lignes : \"" + (r.text || "") + "\"";
        notifType = "request_punishment";
        break;
      case "immunity":
        title = "🛡️ Demande d'immunité";
        body = (r.requestedBy || "Un enfant") + " demande " + r.amount + " lignes d'immunité : \"" + (r.text || "") + "\"";
        notifType = "request_immunity";
        break;
      case "tribunal":
        title = "⚖️ Demande d'ouverture d'affaire";
        body = (r.requestedBy || "Un enfant") + " : \"" + (r.text || "") + "\"";
        notifType = "request_tribunal";
        break;
      case "bonus":
        title = "⭐ Demande de bonus";
        body = (r.requestedBy || "Un enfant") + " demande " + r.amount + " points bonus : \"" + (r.text || "") + "\"";
        notifType = "request_bonus";
        break;
      case "penalty":
        title = "⚠️ Demande de pénalité";
        body = (r.requestedBy || "Un enfant") + " demande une pénalité de " + r.amount + " points : \"" + (r.text || "") + "\"";
        notifType = "request_penalty";
        break;
      case "boutique":
        title = "🛒 Achat en boutique";
        body = (r.requestedBy || "Un enfant") + " a acheté \"" + (r.extra && r.extra.rewardTitle ? r.extra.rewardTitle : "une récompense") + "\" (" + (r.amount || 0) + " pts). À confirmer !";
        notifType = "request_boutique";
        break;
    }

    await sendToFamily(familyId, sender, title, body, {
      type: notifType,
      requestId: context.params.reqId,
      requestType: r.type || "",
      childId: r.childId || "",
    });
  });

// ===== 8. OBJECTIFS (NOUVEAU) =====
exports.onGoalCreated = functions.firestore
  .document("families/{familyId}/goals/{goalId}")
  .onCreate(async (snap, context) => {
    const g = snap.data();
    const familyId = context.params.familyId;
    const sender = g.lastModifiedBy || "";
    const childName = await getChildName(familyId, g.childId);

    await sendToFamilySilent(
      familyId,
      sender,
      "goal_new",
      { goalId: context.params.goalId, childId: g.childId || "", title: "🎯 Nouvel objectif", body: childName + " : " + (g.title || "") }
    );
  });

// ===== 9. NOTES (NOUVEAU) =====
exports.onNoteCreated = functions.firestore
  .document("families/{familyId}/notes/{noteId}")
  .onCreate(async (snap, context) => {
    const n = snap.data();
    const familyId = context.params.familyId;
    const sender = n.lastModifiedBy || "";
    const childName = await getChildName(familyId, n.childId);

    await sendToFamilySilent(
      familyId,
      sender,
      "note_new",
      { noteId: context.params.noteId, childId: n.childId || "", title: "📌 Note", body: childName + " : " + (n.text || "") }
    );
  });

// Note : onCustomBadgeCreated supprimé — pas besoin de notifier pour un badge personnalisé

// ===== 9. DEMANDES DE RATTACHEMENT D'APPAREIL (join_requests) =====
// 🔔 Notifie uniquement le propriétaire de la famille quand un nouvel
// appareil demande à rejoindre. Utilise la même fonction sendToFamily
// mais cible spécifiquement le ownerUid.
exports.onJoinRequestCreated = functions.firestore
  .document("families/{familyId}/join_requests/{requestId}")
  .onCreate(async (snap, context) => {
    const req = snap.data();
    const familyId = context.params.familyId;

    try {
      // Lire le ownerUid de la famille
      const familySnap = await db
        .collection("families")
        .doc(familyId)
        .get();

      if (!familySnap.exists) {
        console.log("onJoinRequestCreated: famille introuvable");
        return;
      }

      const ownerUid = familySnap.data().ownerUid;
      if (!ownerUid) {
        console.log("onJoinRequestCreated: pas de ownerUid sur la famille");
        return;
      }

      // Récupérer les tokens FCM du propriétaire uniquement
      const tokensSnap = await db
        .collection("families")
        .doc(familyId)
        .collection("fcm_tokens")
        .get();

      if (tokensSnap.empty) {
        console.log("onJoinRequestCreated: aucun token FCM trouvé");
        return;
      }

      // 🔒 Filtrer : uniquement les tokens dont uid == ownerUid
      // Ignore les anciens tokens sans uid (pas de migration).
      // Exclut aussi l'appareil demandeur.
      const requesterDeviceId = req.deviceId || "";
      const tokens = [];
      tokensSnap.docs.forEach((doc) => {
        const data = doc.data();
        if (doc.id !== requesterDeviceId &&
            data.uid === ownerUid &&
            data.token) {
          tokens.push(data.token);
        }
      });

      if (tokens.length === 0) {
        console.log("onJoinRequestCreated: aucun token destinataire");
        return;
      }

      const role = req.requestedRole || "parent";
      const deviceName = req.deviceName || "un nouvel appareil";

      const title = "📱 Nouvelle demande de rattachement";
      const body =
        deviceName + " demande à rejoindre la famille en tant que " + role + ".";

      const message = {
        notification: { title, body },
        data: {
          sender: requesterDeviceId,
          type: "join_request",
          requestId: context.params.requestId,
          familyId: familyId,
        },
        android: {
          notification: {
            channelId: "sks_family_channel",
            icon: "@mipmap/ic_launcher",
            sound: "default",
            priority: "high",
          },
        },
        webpush: {
          headers: { Urgency: "high" },
          notification: {
            title: title,
            body: body,
            icon: "/icons/Icon-192.png",
            badge: "/icons/Icon-192.png",
            requireInteraction: true,
          },
          fcmOptions: { link: "https://sks-familly-3f205.web.app" },
        },
        tokens: tokens,
      };

      const response = await admin.messaging().sendEachForMulticast(message);
      console.log(
        "onJoinRequestCreated: envoyé à " +
          response.successCount +
          "/" +
          tokens.length +
          " appareils"
      );
    } catch (e) {
      console.error("onJoinRequestCreated error:", e);
    }
  });
