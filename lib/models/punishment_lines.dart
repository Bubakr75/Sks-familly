import 'package:cloud_firestore/cloud_firestore.dart';

enum PenaltyLinesStatus { pending, completed }

class PenaltyLinesAccess {
  const PenaltyLinesAccess._();

  static bool isValidCount(int? count) =>
      count != null && count > 0 && count <= 10000;

  static List<PunishmentLines> pendingForChild(
    Iterable<PunishmentLines> punishments,
    String childId,
  ) =>
      punishments
          .where((item) => item.childId == childId && item.blocksScreenAccess)
          .toList(growable: false);

  static bool shouldBlockScreenAccess({
    required bool isParentMode,
    required Iterable<PunishmentLines> punishments,
    required String childId,
  }) =>
      !isParentMode && pendingForChild(punishments, childId).isNotEmpty;
}

class PunishmentLines {
  PunishmentLines({
    required this.id,
    required this.childId,
    required this.text,
    required this.totalLines,
    this.completedLines = 0,
    DateTime? createdAt,
    List<String>? photoUrls,
    this.pendingValidation = false,
    this.penaltyHistoryId,
    this.status = PenaltyLinesStatus.pending,
    this.completedAt,
    this.completedBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        photoUrls = photoUrls ?? [];

  String id;
  String childId;
  String text;
  int totalLines;
  int completedLines;
  DateTime createdAt;
  List<String> photoUrls;
  bool pendingValidation;
  String? penaltyHistoryId;
  PenaltyLinesStatus status;
  DateTime? completedAt;
  String? completedBy;

  bool get isLinkedToPenalty =>
      penaltyHistoryId != null && penaltyHistoryId!.trim().isNotEmpty;

  /// Les anciennes punitions restent compatibles avec leur progression.
  bool get isCompleted => isLinkedToPenalty
      ? status == PenaltyLinesStatus.completed
      : completedLines >= totalLines;

  bool get blocksScreenAccess =>
      isLinkedToPenalty && totalLines > 0 && !isCompleted;

  double get progress => totalLines > 0 ? completedLines / totalLines : 0;
  bool get hasPhotos => photoUrls.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'totalLines': totalLines,
        'completedLines': completedLines,
        'createdAt': createdAt.toIso8601String(),
        'photoUrls': photoUrls,
        'pendingValidation': pendingValidation,
        if (penaltyHistoryId != null) 'penaltyHistoryId': penaltyHistoryId,
        if (isLinkedToPenalty) ...{
          'hasPenaltyLines': true,
          'penaltyLinesCount': totalLines,
          'penaltyLinesInstruction': text,
          'penaltyLinesStatus': status.name,
          'penaltyLinesCompletedAt': completedAt?.toIso8601String(),
          'penaltyLinesCompletedBy': completedBy,
        },
      };

  factory PunishmentLines.fromMap(Map<String, dynamic> map) {
    final totalLines = _readPositiveInt(
      map['penaltyLinesCount'] ?? map['totalLines'],
    );
    final linkedId = _readOptionalString(map['penaltyHistoryId']);
    final rawStatus = map['penaltyLinesStatus'];
    final status = rawStatus == 'completed'
        ? PenaltyLinesStatus.completed
        : PenaltyLinesStatus.pending;
    return PunishmentLines(
      id: _readString(map['id']),
      childId: _readString(map['childId']),
      text: _readString(
        map['penaltyLinesInstruction'] ?? map['text'],
      ),
      totalLines: totalLines,
      completedLines: _readNonNegativeInt(map['completedLines']),
      createdAt: _readDate(map['createdAt']),
      photoUrls: _readStringList(map['photoUrls']),
      pendingValidation: map['pendingValidation'] == true,
      penaltyHistoryId: linkedId,
      status: status,
      completedAt: _readNullableDate(map['penaltyLinesCompletedAt']),
      completedBy: _readOptionalString(map['penaltyLinesCompletedBy']),
    );
  }

  static String _readString(dynamic value) => value is String ? value : '';

  static String? _readOptionalString(dynamic value) {
    if (value is! String || value.trim().isEmpty) return null;
    return value.trim();
  }

  static int _readPositiveInt(dynamic value) {
    final parsed = value is num ? value.toInt() : 0;
    return parsed > 0 ? parsed : 0;
  }

  static int _readNonNegativeInt(dynamic value) {
    final parsed = value is num ? value.toInt() : 0;
    return parsed >= 0 ? parsed : 0;
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList();
  }

  static DateTime _readDate(dynamic value) =>
      _readNullableDate(value) ?? DateTime.fromMillisecondsSinceEpoch(0);

  static DateTime? _readNullableDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
