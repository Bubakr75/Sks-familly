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
  List<String> readBy;

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
    List<String>? readBy,
  })  : createdAt = createdAt ?? DateTime.now(),
        extra = extra ?? {},
        readBy = readBy ?? [];

  bool get isPending =>
      status == 'pending' ||
      status == 'sending' ||
      status == 'sent' ||
      status == 'received';

  bool isUnreadFor(String? uid) =>
      uid != null && uid.isNotEmpty && !readBy.contains(uid);

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
        'readBy': readBy,
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
        readBy: map['readBy'] is List
            ? List<String>.from(map['readBy'])
            : const [],
      );
}
