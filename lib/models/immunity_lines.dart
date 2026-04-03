// lib/models/immunity_lines.dart
import 'package:flutter/material.dart';

class ImmunityLines {
  String id;
  String childId;
  String reason;
  int lines;
  int usedLines;
  DateTime createdAt;
  DateTime? expiresAt;

  ImmunityLines({
    required this.id,
    required this.childId,
    required this.reason,
    required this.lines,
    this.usedLines = 0,
    DateTime? createdAt,
    this.expiresAt,
  }) : createdAt = createdAt ?? DateTime.now();

  // ── Getters existants ──────────────────────────────────
  int get availableLines => lines - usedLines;
  bool get isFullyUsed => availableLines <= 0;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isUsable => !isExpired && availableLines > 0;

  // ── Getters manquants ajoutés ──────────────────────────
  bool get isActive => isUsable;

  String get name => reason;

  int get linesGranted => lines;

  String get typeLabel => 'Immunité';

  Color get typeColor => const Color(0xFF00E676);

  IconData get typeIcon => Icons.shield_rounded;

  // ── Labels ─────────────────────────────────────────────
  String get expiresLabel {
    if (expiresAt == null) return 'Pas d\'expiration';
    if (isExpired) return 'Expirée';
    final diff = expiresAt!.difference(DateTime.now());
    if (diff.inDays > 0) return 'Expire dans ${diff.inDays}j';
    if (diff.inHours > 0) return 'Expire dans ${diff.inHours}h';
    return 'Expire bientôt';
  }

  String get statusLabel {
    if (isExpired) return 'Expirée';
    if (isFullyUsed) return 'Entièrement utilisée';
    return '$availableLines lignes disponibles';
  }

  // ── Sérialisation ──────────────────────────────────────
  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'reason': reason,
        'lines': lines,
        'usedLines': usedLines,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt?.toIso8601String(),
      };

  factory ImmunityLines.fromMap(Map<String, dynamic> map) => ImmunityLines(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        reason: map['reason'] ?? '',
        lines: map['lines'] ?? 0,
        usedLines: map['usedLines'] ?? 0,
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        expiresAt: map['expiresAt'] != null
            ? DateTime.parse(map['expiresAt'])
            : null,
      );
}
