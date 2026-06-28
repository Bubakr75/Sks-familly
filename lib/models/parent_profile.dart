import 'dart:convert';

/// Modèle pour un profil parent (papa, maman, tata, etc.)
class ParentProfile {
  String id;
  String name;
  String? photoBase64;
  String? securityQuestion;
  String? securityAnswerHashed;
  DateTime createdAt;

  ParentProfile({
    required this.id,
    required this.name,
    this.photoBase64,
    this.securityQuestion,
    this.securityAnswerHashed,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  bool get hasPhoto => photoBase64 != null && photoBase64!.isNotEmpty;
  bool get hasSecurityQuestion =>
      securityQuestion != null && securityQuestion!.isNotEmpty;

  String get initial =>
      name.isNotEmpty ? name[0].toUpperCase() : '?';

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'photoBase64': photoBase64,
        'securityQuestion': securityQuestion,
        'securityAnswerHashed': securityAnswerHashed,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ParentProfile.fromMap(Map<String, dynamic> map) => ParentProfile(
        id: map['id'] ?? '',
        name: map['name'] ?? 'Parent',
        photoBase64: map['photoBase64'],
        securityQuestion: map['securityQuestion'],
        securityAnswerHashed: map['securityAnswerHashed'],
        createdAt: map['createdAt'] != null
            ? DateTime.parse(map['createdAt'])
            : DateTime.now(),
      );

  ParentProfile copyWith({
    String? id,
    String? name,
    String? photoBase64,
    String? securityQuestion,
    String? securityAnswerHashed,
    DateTime? createdAt,
  }) =>
      ParentProfile(
        id: id ?? this.id,
        name: name ?? this.name,
        photoBase64: photoBase64 ?? this.photoBase64,
        securityQuestion: securityQuestion ?? this.securityQuestion,
        securityAnswerHashed: securityAnswerHashed ?? this.securityAnswerHashed,
        createdAt: createdAt ?? this.createdAt,
      );
}
