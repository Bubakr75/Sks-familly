import 'package:cloud_firestore/cloud_firestore.dart';

class HistoryEntry {
  String id;
  String childId;
  int points;
  String reason;
  String category;
  DateTime date;
  bool isBonus;
  String? proofPhotoBase64;
  String? actionBy;
  String? actorUid;
  String? actorDisplayName;
  String? actorRole;
  String? proofPhotoPath;
  String? transferId;
  String? counterpartyChildId;

  HistoryEntry({
    required this.id,
    required this.childId,
    required this.points,
    required this.reason,
    this.category = 'Bonus',
    DateTime? date,
    this.isBonus = true,
    this.proofPhotoBase64,
    this.actionBy,
    this.actorUid,
    this.actorDisplayName,
    this.actorRole,
    this.proofPhotoPath,
    this.transferId,
    this.counterpartyChildId,
  }) : date = date ?? DateTime.now();

  bool get hasProofPhoto =>
      (proofPhotoPath != null && proofPhotoPath!.isNotEmpty) ||
      (proofPhotoBase64 != null && proofPhotoBase64!.isNotEmpty);

  /// Nom fiable fourni par le serveur, avec compatibilité des anciennes entrées.
  String get displayActorName {
    final serverName = actorDisplayName?.trim() ?? '';
    if (serverName.isNotEmpty) return serverName;
    final legacyName = actionBy?.trim() ?? '';
    return legacyName.isNotEmpty ? legacyName : 'un parent';
  }

  String get actionDescription {
    final action = isBonus ? 'Bonus' : 'Pénalité';
    return '$action de $points points '
        '${isBonus ? 'ajouté' : 'ajoutée'} par $displayActorName';
  }

  /// Achat effectué dans la boutique.
  bool get isPurchase => category.toLowerCase() == 'boutique';

  /// Véritable pénalité : un achat boutique ou un transfert n'est jamais une pénalité.
  bool get isPenalty => !isBonus && !isPurchase && !isPointsTransfer;

  /// Transfert de points entre enfants (ne compte ni comme bonus ni comme pénalité).
  bool get isPointsTransfer =>
      category == 'points_transfer_out' || category == 'points_transfer_in';

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'points': points,
        'reason': reason,
        'category': category,
        'date': date.toIso8601String(),
        'isBonus': isBonus,
        'proofPhotoBase64': proofPhotoBase64,
        'actionBy': actionBy,
        if (actorUid != null) 'actorUid': actorUid,
        if (actorDisplayName != null) 'actorDisplayName': actorDisplayName,
        if (actorRole != null) 'actorRole': actorRole,
        if (proofPhotoPath != null) 'proofPhotoPath': proofPhotoPath,
        if (transferId != null) 'transferId': transferId,
        if (counterpartyChildId != null)
          'counterpartyChildId': counterpartyChildId,
      };

  factory HistoryEntry.fromMap(Map<String, dynamic> map) => HistoryEntry(
        id: map['id'] ?? '',
        childId: map['childId'] ?? '',
        points: map['points'] ?? 0,
        reason: map['reason'] ?? '',
        category: map['category'] ?? 'Bonus',
        date: _readDate(map['createdAt'] ?? map['date']),
        isBonus: map['isBonus'] ?? true,
        proofPhotoBase64: map['proofPhotoBase64'],
        actionBy: map['actionBy'],
        actorUid: map['actorUid'],
        actorDisplayName: map['actorDisplayName'],
        actorRole: map['actorRole'],
        proofPhotoPath: map['proofPhotoPath'],
        transferId: map['transferId'],
        counterpartyChildId: map['counterpartyChildId'],
      );

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
    return DateTime.now();
  }
}
