class NoteModel {
  String id;
  String childId;
  String text;
  String authorName;
  DateTime createdAt;
  bool isPinned;

  bool isEvaluation;
  int? aiScore;
  int? parentScore;
  int? overallScore;
  Map<String, int> categoryScores;

  NoteModel({
    required this.id,
    required this.childId,
    required this.text,
    this.authorName = 'Parent',
    DateTime? createdAt,
    this.isPinned = false,
    this.isEvaluation = false,
    this.aiScore,
    this.parentScore,
    this.overallScore,
    Map<String, int>? categoryScores,
  })  : createdAt = createdAt ?? DateTime.now(),
        categoryScores = Map<String, int>.from(categoryScores ?? const {});

  Map<String, dynamic> toMap() => {
        'id': id,
        'childId': childId,
        'text': text,
        'authorName': authorName,
        'createdAt': createdAt.toIso8601String(),
        'isPinned': isPinned,
        'isEvaluation': isEvaluation,
        if (aiScore != null) 'aiScore': aiScore,
        if (parentScore != null) 'parentScore': parentScore,
        if (overallScore != null) 'overallScore': overallScore,
        if (categoryScores.isNotEmpty) 'categoryScores': categoryScores,
      };

  factory NoteModel.fromMap(Map<String, dynamic> map) {
    final text = map['text']?.toString() ?? '';
    final legacy = _parseLegacyEvaluation(text);

    final rawCategories = map['categoryScores'];
    final categories = <String, int>{};

    if (rawCategories is Map) {
      for (final entry in rawCategories.entries) {
        final score = _asInt(entry.value);
        if (score != null) {
          categories[entry.key.toString()] = score.clamp(0, 20);
        }
      }
    }

    if (categories.isEmpty && legacy != null) {
      categories.addAll(
        Map<String, int>.from(legacy['categoryScores'] as Map),
      );
    }

    final createdAt =
        DateTime.tryParse(map['createdAt']?.toString() ?? '') ?? DateTime.now();

    return NoteModel(
      id: map['id']?.toString() ?? '',
      childId: map['childId']?.toString() ?? '',
      text: text,
      authorName: map['authorName']?.toString() ?? 'Parent',
      createdAt: createdAt,
      isPinned: map['isPinned'] == true,
      isEvaluation: map['isEvaluation'] == true || legacy != null,
      aiScore: _asInt(map['aiScore']) ?? legacy?['aiScore'] as int?,
      parentScore: _asInt(map['parentScore']) ?? legacy?['parentScore'] as int?,
      overallScore:
          _asInt(map['overallScore']) ?? legacy?['overallScore'] as int?,
      categoryScores: categories,
    );
  }

  static int? _asInt(dynamic value) {
    if (value is num) return value.round().clamp(0, 20);
    return int.tryParse(value?.toString() ?? '')?.clamp(0, 20);
  }

  static Map<String, dynamic>? _parseLegacyEvaluation(String text) {
    if (!text.startsWith('Bulletin:')) return null;

    int? readScore(String label) {
      final match = RegExp(
        '${RegExp.escape(label)}=(\\d{1,2})/20',
      ).firstMatch(text);

      return _asInt(match?.group(1));
    }

    final categories = <String, int>{};

    for (final category in const [
      'Respect',
      'Coopération',
      'Autonomie',
      'Gestion des émotions',
    ]) {
      final score = readScore(category);
      if (score != null) categories[category] = score;
    }

    return {
      'aiScore': readScore('IA'),
      'parentScore': readScore('Parent'),
      'overallScore': readScore('Moy'),
      'categoryScores': categories,
    };
  }
}
