class TradeModel {
  String id;
  String fromChildId;
  String toChildId;
  int immunityLines;
  String serviceDescription;
  String status; // pending, accepted, service_done, completed, rejected, cancelled
  DateTime createdAt;
  DateTime? acceptedAt;
  DateTime? completedAt;
  String? parentValidatorNote;

  TradeModel({
    required this.id,
    required this.fromChildId,
    required this.toChildId,
    required this.immunityLines,
    required this.serviceDescription,
    this.status = 'pending',
    DateTime? createdAt,
    this.acceptedAt,
    this.completedAt,
    this.parentValidatorNote,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isServiceDone => status == 'service_done';
  bool get isCompleted => status == 'completed';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get isActive => isPending || isAccepted || isServiceDone;

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'En attente';
      case 'accepted':
        return 'Accepte - service a rendre';
      case 'service_done':
        return 'Service rendu - validation parent';
      case 'completed':
        return 'Termine';
      case 'rejected':
        return 'Refuse';
      case 'cancelled':
        return 'Annule';
      default:
        return status;
    }
  }

  String get statusEmoji {
    switch (status) {
      case 'pending':
        return '\u{23F3}';
      case 'accepted':
        return '\u{1F91D}';
      case 'service_done':
        return '\u{2705}';
      case 'completed':
        return '\u{1F3C6}';
      case 'rejected':
        return '\u{274C}';
      case 'cancelled':
        return '\u{1F6AB}';
      default:
        return '\u{2753}';
    }
      TradeModel copyWith({
    String? id,
    String? fromChildId,
    String? toChildId,
    int? immunityLines,
    String? serviceDescription,
    String? status,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? parentValidatorNote,
  }) {
    return TradeModel(
      id: id ?? this.id,
      fromChildId: fromChildId ?? this.fromChildId,
      toChildId: toChildId ?? this.toChildId,
      immunityLines: immunityLines ?? this.immunityLines,
      serviceDescription: serviceDescription ?? this.serviceDescription,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      parentValidatorNote: parentValidatorNote ?? this.parentValidatorNote,
    );
  }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'fromChildId': fromChildId,
        'toChildId': toChildId,
        'immunityLines': immunityLines,
        'serviceDescription': serviceDescription,
        'status': status,
        'createdAt': createdAt.toIso8601String(),
        'acceptedAt': acceptedAt?.toIso8601String(),
        'completedAt': completedAt?.toIso8601String(),
        'parentValidatorNote': parentValidatorNote,
      };

  factory TradeModel.fromMap(Map<String, dynamic> map) => TradeModel(
        id: map['id'] ?? '',
        fromChildId: map['fromChildId'] ?? '',
        toChildId: map['toChildId'] ?? '',
        immunityLines: map['immunityLines'] ?? 0,
        serviceDescription: map['serviceDescription'] ?? '',
        status: map['status'] ?? 'pending',
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
        acceptedAt: map['acceptedAt'] != null
            ? DateTime.parse(map['acceptedAt'])
            : null,
        completedAt: map['completedAt'] != null
            ? DateTime.parse(map['completedAt'])
            : null,
        parentValidatorNote: map['parentValidatorNote'],
      );
}
