"use strict";

function normalizeTribunalCase(data, cleanId) {
  const input = data.tribunal;
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("INVALID_TRIBUNAL");
  }
  const text = (value, max, required) => {
    if (typeof value !== "string" || value.trim().length > max ||
        (required && !value.trim()) || /[\u0000-\u0008\u000b\u000c\u000e-\u001f]/.test(value)) {
      throw new Error("INVALID_TRIBUNAL_TEXT");
    }
    return value.trim();
  };
  const plaintiffId = cleanId(input.plaintiffId, "plaintiff_id");
  const accusedId = cleanId(input.accusedId, "accused_id");
  if (plaintiffId === accusedId) throw new Error("INVALID_TRIBUNAL_PARTIES");
  const participants = [
    {childId: plaintiffId, role: "plaintiff"},
    {childId: accusedId, role: "accused"},
  ];
  if (input.participants !== undefined && !Array.isArray(input.participants)) {
    throw new Error("INVALID_TRIBUNAL_PARTICIPANTS");
  }
  if ((input.participants || []).length > 20) throw new Error("INVALID_TRIBUNAL_PARTICIPANTS");
  for (const participant of input.participants || []) {
    if (!participant || typeof participant !== "object") throw new Error("INVALID_TRIBUNAL_PARTICIPANT");
    const childId = cleanId(participant.childId, "participant_id");
    const role = participant.role;
    if (role === "plaintiff" && childId === plaintiffId || role === "accused" && childId === accusedId) continue;
    if (!["prosecutionLawyer", "defenseLawyer", "witness"].includes(role) ||
        participants.some(p => p.childId === childId) ||
        (role !== "witness" && participants.some(p => p.role === role))) {
      throw new Error("INVALID_TRIBUNAL_PARTICIPANT");
    }
    participants.push({childId, role});
  }
  return {
    title: text(input.title, 200, true),
    description: text(input.description ?? "", 4000, false),
    plaintiffId, accusedId, participants,
    ...(data.senderDeviceId ? {senderDeviceId: cleanId(data.senderDeviceId, "sender_device_id")} : {}),
  };
}

function buildTribunalCase(op, sender) {
  return {
    id: op.operationId, title: op.title, description: op.description,
    plaintiffId: op.plaintiffId, accusedId: op.accusedId,
    participants: op.participants.map(p => ({...p, testimony: null,
      testimonyVerified: null, pointsAwarded: 0})),
    votes: [], status: "filed", verdict: null, verdictReason: null,
    filedDate: new Date().toISOString(), scheduledDate: null, verdictDate: null,
    plaintiffPoints: 0, accusedPoints: 0, votingEnabled: false,
    lastModifiedBy: sender,
  };
}

module.exports = {normalizeTribunalCase, buildTribunalCase};
