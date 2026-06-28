class PendingRequest {
  String id;
  String type;        // 'punishment' | 'immunity' | 'bonus' | 'tribunal'
  String childId;     // enfant concerne
  String requestedBy; // nom de l'enfant qui propose
  String text;        // description / raison / texte
  int amount;         // nb de lignes (punition/immunite) ou points (bonus)
  String status;      // 'pending' | 'approved' | 'rejected'
  DateTime createdAt;
  Map<String, dynamic> extra; // donnees additionnelles (tribunal, etc.)

  PendingRequest({
    required this.id,
    required this.type,
    required this.childId,
    required this.requestedBy,
    required this.text,
    this.amount = 0,
    this.status = 'pending',
    DateTime? createdAt,
    Map<String, dynamic>? extra,
  })  : createdAt = createdAt ?? DateTime.now(),
        extra = extra ?? {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'type': type,
        'childId': childId,
        'requestedBy': requestedBy,
        'text': text,
        'amount': amount,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'extra': extra,
      };

  factory PendingRequest.fromMap(Map<String, dynamic> map) => PendingRequest(
        id: map['id'] ?? '',
        type: map['type'] ?? '',
        childId: map['childId'] ?? '',
        requestedBy: map['requestedBy'] ?? '',
        text: map['text'] ?? '',
        amount: map['amount'] ?? 0,
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        extra: map['extra'] != null
            ? Map<String, dynamic>.from(map['extra'])
            : {},
      );
}
