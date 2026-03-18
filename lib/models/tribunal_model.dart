import 'package:flutter/material.dart';

enum TribunalStatus { filed, scheduled, inProgress, deliberation, verdict, closed }

enum TribunalVerdict { guilty, innocent, dismissed }

enum TribunalRole { plaintiff, accused, prosecutionLawyer, defenseLawyer, witness }

class TribunalParticipant {
  final String childId;
  final TribunalRole role;
  String? testimony;
  bool? testimonyVerified;
  int pointsAwarded;

  TribunalParticipant({
    required this.childId,
    required this.role,
    this.testimony,
    this.testimonyVerified,
    this.pointsAwarded = 0,
  });

  Map<String, dynamic> toMap() => {
        'childId': childId,
        'role': role.name,
        'testimony': testimony,
        'testimonyVerified': testimonyVerified,
        'pointsAwarded': pointsAwarded,
      };

  factory TribunalParticipant.fromMap(Map<String, dynamic> map) => TribunalParticipant(
        childId: map['childId'] ?? '',
        role: TribunalRole.values.firstWhere((r) => r.name == map['role'], orElse: () => TribunalRole.witness),
        testimony: map['testimony'],
        testimonyVerified: map['testimonyVerified'],
        pointsAwarded: map['pointsAwarded'] ?? 0,
      );
}

class TribunalCase {
  String id;
  String title;
  String description;
  String plaintiffId;
  String accusedId;
  List<TribunalParticipant> participants;
  TribunalStatus status;
  TribunalVerdict? verdict;
  String? verdictReason;
  DateTime filedDate;
  DateTime? scheduledDate;
  DateTime? verdictDate;
  int plaintiffPoints;
  int accusedPoints;

  TribunalCase({
    required this.id,
    required this.title,
    required this.description,
    required this.plaintiffId,
    required this.accusedId,
    List<TribunalParticipant>? participants,
    this.status = TribunalStatus.filed,
    this.verdict,
    this.verdictReason,
    DateTime? filedDate,
    this.scheduledDate,
    this.verdictDate,
    this.plaintiffPoints = 0,
    this.accusedPoints = 0,
  })  : participants = participants ?? [],
        filedDate = filedDate ?? DateTime.now();

  TribunalParticipant? getParticipant(TribunalRole role) {
    try {
      return participants.firstWhere((p) => p.role == role);
    } catch (_) {
      return null;
    }
  }

  List<TribunalParticipant> get witnesses => participants.where((p) => p.role == TribunalRole.witness).toList();
  TribunalParticipant? get prosecutionLawyer => getParticipant(TribunalRole.prosecutionLawyer);
  TribunalParticipant? get defenseLawyer => getParticipant(TribunalRole.defenseLawyer);
  bool get isClosed => status == TribunalStatus.verdict || status == TribunalStatus.closed;

  bool get isToday {
    if (scheduledDate == null) return false;
    final now = DateTime.now();
    return scheduledDate!.year == now.year && scheduledDate!.month == now.month && scheduledDate!.day == now.day;
  }

  Color get statusColor {
    switch (status) {
      case TribunalStatus.filed: return const Color(0xFFFF9100);
      case TribunalStatus.scheduled: return const Color(0xFF448AFF);
      case TribunalStatus.inProgress: return const Color(0xFFFF1744);
      case TribunalStatus.deliberation: return const Color(0xFF7C4DFF);
      case TribunalStatus.verdict: return const Color(0xFF00E676);
      case TribunalStatus.closed: return const Color(0xFF9E9E9E);
    }
  }

  String get statusLabel {
    switch (status) {
      case TribunalStatus.filed: return 'Plainte deposee';
      case TribunalStatus.scheduled: return 'Audience prevue';
      case TribunalStatus.inProgress: return 'En audience';
      case TribunalStatus.deliberation: return 'Deliberation';
      case TribunalStatus.verdict: return 'Verdict rendu';
      case TribunalStatus.closed: return 'Classe sans suite';
    }
  }

  String get statusEmoji {
    switch (status) {
      case TribunalStatus.filed: return '\u{1F4DD}';
      case TribunalStatus.scheduled: return '\u{1F4C5}';
      case TribunalStatus.inProgress: return '\u{2696}';
      case TribunalStatus.deliberation: return '\u{1F914}';
      case TribunalStatus.verdict: return '\u{1F528}';
      case TribunalStatus.closed: return '\u{1F4C1}';
    }
  }

  String get verdictEmoji {
    switch (verdict) {
      case TribunalVerdict.guilty: return '\u{274C}';
      case TribunalVerdict.innocent: return '\u{2705}';
      case TribunalVerdict.dismissed: return '\u{1F5C4}';
      case null: return '\u{2753}';
    }
  }

  String get verdictLabel {
    switch (verdict) {
      case TribunalVerdict.guilty: return 'Coupable';
      case TribunalVerdict.innocent: return 'Innocent';
      case TribunalVerdict.dismissed: return 'Classe sans suite';
      case null: return 'En attente';
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'description': description,
        'plaintiffId': plaintiffId,
        'accusedId': accusedId,
        'participants': participants.map((p) => p.toMap()).toList(),
        'status': status.name,
        'verdict': verdict?.name,
        'verdictReason': verdictReason,
        'filedDate': filedDate.toIso8601String(),
        'scheduledDate': scheduledDate?.toIso8601String(),
        'verdictDate': verdictDate?.toIso8601String(),
        'plaintiffPoints': plaintiffPoints,
        'accusedPoints': accusedPoints,
      };

  factory TribunalCase.fromMap(Map<String, dynamic> map) => TribunalCase(
        id: map['id'] ?? '',
        title: map['title'] ?? '',
        description: map['description'] ?? '',
        plaintiffId: map['plaintiffId'] ?? '',
        accusedId: map['accusedId'] ?? '',
        participants: (map['participants'] as List<dynamic>?)
                ?.map((p) => TribunalParticipant.fromMap(Map<String, dynamic>.from(p)))
                .toList() ??
            [],
        status: TribunalStatus.values.firstWhere((s) => s.name == map['status'], orElse: () => TribunalStatus.filed),
        verdict: map['verdict'] != null
            ? TribunalVerdict.values.firstWhere((v) => v.name == map['verdict'], orElse: () => TribunalVerdict.dismissed)
            : null,
        verdictReason: map['verdictReason'],
        filedDate: map['filedDate'] != null ? DateTime.parse(map['filedDate']) : DateTime.now(),
        scheduledDate: map['scheduledDate'] != null ? DateTime.parse(map['scheduledDate']) : null,
        verdictDate: map['verdictDate'] != null ? DateTime.parse(map['verdictDate']) : null,
        plaintiffPoints: map['plaintiffPoints'] ?? 0,
        accusedPoints: map['accusedPoints'] ?? 0,
      );
}
