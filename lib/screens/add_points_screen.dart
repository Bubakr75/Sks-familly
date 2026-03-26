import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen> {
  String? _selectedChildId;
  bool _isBonus = true;
  String _reason = '';
  String _customReason = '';
  int _points = 1;
  File? _proofPhoto;
  final _customReasonController = TextEditingController();

  final List<String> _bonusReasons = [
    'Devoirs faits',
    'Chambre rangée',
    'Bon comportement',
    'Aide ménage',
    'Lecture',
    'Sport',
    'Politesse',
    'Initiative',
  ];

  final List<String> _penaltyReasons = [
    'Désobéissance',
    'Bagarre',
    'Mensonge',
    'Écran abusif',
    'Désordre',
    'Retard',
    'Insolence',
    'Devoirs non faits',
  ];

  @override
  void dispose() {
    _customReasonController.dispose();
    super.dispose();
  }

  List<String> get _currentReasons => _isBonus ? _bonusReasons : _penaltyReasons;

  void _submitPoints() {
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionnez un enfant')),
      );
      return;
    }

    final finalReason = _reason.isNotEmpty
        ? _reason
        : _customReason.isNotEmpty
            ? _customReason
            : null;

    if (finalReason == null || finalReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indiquez une raison')),
      );
      return;
    }

    final provider = context.read<FamilyProvider>();
    final actualPoints = _isBonus ? _points : -_points;

    provider.addPoints(
      childId: _selectedChildId!,
      points: actualPoints,
      reason: finalReason,
      category: _isBonus ? 'bonus' : 'penalty',
      proofPath: _proofPhoto?.path,
    );

    HapticFeedback.mediumImpact();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${_isBonus ? '+' : ''}$actualPoints points attribués !',
        ),
        backgroundColor: _isBonus ? Colors.green : Colors.redAccent,
      ),
    );

    setState(() {
      _reason = '';
      _customReason = '';
      _customReasonController.clear();
      _points = 1;
      _proofPhoto = null;
    });
  }

  Future<void> _pickPhoto() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Photo preuve',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                TvFocusWrapper(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await ImagePicker()
                        .pickImage(source: ImageSource.camera);
                    if (picked != null) {
                      setState(() => _proofPhoto = File(picked.path));
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.camera_alt, color: Colors.cyanAccent),
                    title: const Text('Caméra',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                TvFocusWrapper(
                  onTap: () async {
                    Navigator.pop(ctx);
                    final picked = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (picked != null) {
                      setState(() => _proofPhoto = File(picked.path));
                    }
                  },
                  child: ListTile(
                    leading: const Icon(Icons.photo_library, color: Colors.purpleAccent),
                    title: const Text('Galerie',
                        style: TextStyle(color: Colors.white)),
                  ),
                ),
                if (_proofPhoto != null)
                  TvFocusWrapper(
                    onTap: () {
                      setState(() => _proofPhoto = null);
                      Navigator.pop(ctx);
                    },
                    child: ListTile(
                      leading: const Icon(Icons.delete, color: Colors.redAccent),
                      title: const Text('Supprimer la photo',
                          style: TextStyle(color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final children = provider.children;

    return AnimatedBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Attribuer des points'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // === Sélection enfant ===
              const Text(
                'Enfant',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: children.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final child = children[index];
                    final isSelected = _selectedChildId == child.id;

                    return TvFocusWrapper(
                      onTap: () {
                        setState(() => _selectedChildId = child.id);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.cyanAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? Colors.cyanAccent
                                : Colors.white24,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 18,
                              backgroundColor: Colors.cyanAccent.withOpacity(0.3),
                              child: Text(
                                child.name.isNotEmpty
                                    ? child.name[0].toUpperCase()
                                    : '?',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              child.name,
                              style: TextStyle(
                                color: isSelected
                                    ? Colors.cyanAccent
                                    : Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),

              // === Toggle Bonus / Pénalité ===
              Row(
                children: [
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () => setState(() => _isBonus = true),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: _isBonus
                              ? Colors.greenAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _isBonus
                                ? Colors.greenAccent
                                : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thumb_up_rounded,
                                  color: _isBonus
                                      ? Colors.greenAccent
                                      : Colors.white38,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Bonus',
                                style: TextStyle(
                                  color: _isBonus
                                      ? Colors.greenAccent
                                      : Colors.white38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TvFocusWrapper(
                      onTap: () => setState(() => _isBonus = false),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          color: !_isBonus
                              ? Colors.redAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: !_isBonus
                                ? Colors.redAccent
                                : Colors.white24,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.thumb_down_rounded,
                                  color: !_isBonus
                                      ? Colors.redAccent
                                      : Colors.white38,
                                  size: 20),
                              const SizedBox(width: 8),
                              Text(
                                'Pénalité',
                                style: TextStyle(
                                  color: !_isBonus
                                      ? Colors.redAccent
                                      : Colors.white38,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // === Raisons rapides ===
              const Text(
                'Raison rapide',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _currentReasons.map((r) {
                  final isSelected = _reason == r;
                  return TvFocusWrapper(
                    onTap: () {
                      setState(() {
                        _reason = isSelected ? '' : r;
                        if (_reason.isNotEmpty) {
                          _customReason = '';
                          _customReasonController.clear();
                        }
                      });
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? (_isBonus
                                ? Colors.greenAccent.withOpacity(0.25)
                                : Colors.redAccent.withOpacity(0.25))
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? (_isBonus
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              : Colors.white24,
                        ),
                      ),
                      child: Text(
                        r,
                        style: TextStyle(
                          color: isSelected
                              ? (_isBonus
                                  ? Colors.greenAccent
                                  : Colors.redAccent)
                              : Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              // === Raison personnalisée ===
              TextField(
                controller: _customReasonController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ou saisissez une raison...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.06),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Colors.cyanAccent),
                  ),
                ),
                onChanged: (val) {
                  setState(() {
                    _customReason = val;
                    if (val.isNotEmpty) _reason = '';
                  });
                },
              ),
              const SizedBox(height: 24),

              // === Points ===
              const Text(
                'Nombre de points',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TvFocusWrapper(
                    onTap: () {
                      if (_points > 1) setState(() => _points--);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.remove, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 24),
                  Text(
                    '$_points',
                    style: TextStyle(
                      color: _isBonus ? Colors.greenAccent : Colors.redAccent,
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 24),
                  TvFocusWrapper(
                    onTap: () {
                      if (_points < 50) setState(() => _points++);
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withOpacity(0.1),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Icon(Icons.add, color: Colors.white70),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Raccourcis points
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [1, 2, 5, 10].map((val) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: TvFocusWrapper(
                      onTap: () => setState(() => _points = val),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          color: _points == val
                              ? Colors.cyanAccent.withOpacity(0.2)
                              : Colors.white.withOpacity(0.06),
                          border: Border.all(
                            color: _points == val
                                ? Colors.cyanAccent
                                : Colors.white24,
                          ),
                        ),
                        child: Text(
                          '$val',
                          style: TextStyle(
                            color: _points == val
                                ? Colors.cyanAccent
                                : Colors.white70,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),

              // === Photo preuve ===
              TvFocusWrapper(
                onTap: _pickPhoto,
                child: GlassCard(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          _proofPhoto != null
                              ? Icons.check_circle
                              : Icons.camera_alt_outlined,
                          color: _proofPhoto != null
                              ? Colors.greenAccent
                              : Colors.white54,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _proofPhoto != null
                              ? 'Photo ajoutée'
                              : 'Ajouter une photo preuve',
                          style: TextStyle(
                            color: _proofPhoto != null
                                ? Colors.greenAccent
                                : Colors.white70,
                          ),
                        ),
                        const Spacer(),
                        if (_proofPhoto != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _proofPhoto!,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // === Bouton Valider ===
              SizedBox(
                width: double.infinity,
                height: 56,
                child: TvFocusWrapper(
                  onTap: _submitPoints,
                  child: ElevatedButton(
                    onPressed: _submitPoints,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isBonus
                          ? Colors.greenAccent.shade700
                          : Colors.redAccent.shade700,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                    ),
                    child: Text(
                      _isBonus
                          ? 'Attribuer +$_points points'
                          : 'Retirer $_points points',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
