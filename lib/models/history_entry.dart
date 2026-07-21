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
    this.transferId,
    this.counterpartyChildId,
  }) : date = date ?? DateTime.now();

  bool get hasProofPhoto =>
      proofPhotoBase64 != null && proofPhotoBase64!.isNotEmpty;

  /// Achat effectué dans la boutique.
  bool get isPurchase => category.toLowerCase() == 'boutique';

  /// Véritable pénalité : un achat boutique n'est jamais une pénalité.
  bool get isPenalty => !isBonus && !isPurchase;

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
        date:
            map['date'] != null ? DateTime.parse(map['date']) : DateTime.now(),
        isBonus: map['isBonus'] ?? true,
        proofPhotoBase64: map['proofPhotoBase64'],
        actionBy: map['actionBy'],
        transferId: map['transferId'],
        counterpartyChildId: map['counterpartyChildId'],
      );
}
