import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../models/child_model.dart';
import '../widgets/animated_background.dart';
import '../widgets/glass_card.dart';
import '../widgets/tv_focus_wrapper.dart';

// ==================== ANIMATIONS ====================

class _StarExplosion extends StatefulWidget {
  const _StarExplosion();
  @override
  State<_StarExplosion> createState() => _StarExplosionState();
}

class _StarExplosionState extends State<_StarExplosion>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _StarBurstPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _StarBurstPainter extends CustomPainter {
  final double progress;
  _StarBurstPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final random = Random(42);

    for (int i = 0; i < 12; i++) {
      final angle = (i * pi * 2 / 12) + (progress * pi * 0.5);
      final distance = progress * size.width * 0.4;
      final starCenter = Offset(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );

      final paint = Paint()
        ..color = Colors.amber.withOpacity(1.0 - progress)
        ..style = PaintingStyle.fill;

      final starSize = (1.0 - progress) * (8 + random.nextDouble() * 8);
      _drawStar(canvas, starCenter, starSize, paint);
    }

    final glowPaint = Paint()
      ..color = Colors.amber.withOpacity((1.0 - progress) * 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20);
    canvas.drawCircle(center, (1.0 - progress) * 40, glowPaint);
  }

  void _drawStar(Canvas canvas, Offset center, double size, Paint paint) {
    final path = Path();
    for (int i = 0; i < 5; i++) {
      final outerAngle = (i * 4 * pi / 5) - pi / 2;
      final innerAngle = outerAngle + 2 * pi / 10;
      final outerPoint = Offset(
        center.dx + cos(outerAngle) * size,
        center.dy + sin(outerAngle) * size,
      );
      final innerPoint = Offset(
        center.dx + cos(innerAngle) * size * 0.4,
        center.dy + sin(innerAngle) * size * 0.4,
      );
      if (i == 0) {
        path.moveTo(outerPoint.dx, outerPoint.dy);
      } else {
        path.lineTo(outerPoint.dx, outerPoint.dy);
      }
      path.lineTo(innerPoint.dx, innerPoint.dy);
    }
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _StarBurstPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

class _PenaltyFlash extends StatefulWidget {
  const _PenaltyFlash();
  @override
  State<_PenaltyFlash> createState() => _PenaltyFlashState();
}

class _PenaltyFlashState extends State<_PenaltyFlash>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(200, 200),
          painter: _ImpactPainter(progress: _controller.value),
        );
      },
    );
  }
}

class _ImpactPainter extends CustomPainter {
  final double progress;
  _ImpactPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    for (int i = 0; i < 3; i++) {
      final ringProgress = (progress - i * 0.15).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Colors.red.withOpacity((1.0 - ringProgress) * 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = (1.0 - ringProgress) * 4;
      canvas.drawCircle(center, ringProgress * size.width * 0.4, paint);
    }

    for (int i = 0; i < 8; i++) {
      final angle = i * pi * 2 / 8;
      final startDist = progress * size.width * 0.15;
      final endDist = progress * size.width * 0.35;
      final paint = Paint()
        ..color = Colors.redAccent.withOpacity(1.0 - progress)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(
        Offset(center.dx + cos(angle) * startDist,
            center.dy + sin(angle) * startDist),
        Offset(center.dx + cos(angle) * endDist,
            center.dy + sin(angle) * endDist),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ImpactPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

void showPointsAnimation(BuildContext context, {required bool isBonus}) {
  showDialog(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: false,
    builder: (ctx) {
      Future.delayed(const Duration(milliseconds: 1800), () {
        if (ctx.mounted) Navigator.of(ctx).pop();
      });
      return Center(
        child: isBonus ? const _StarExplosion() : const _PenaltyFlash(),
      );
    },
  );
}

// ==================== ADD POINTS SCREEN ====================

class AddPointsScreen extends StatefulWidget {
  final String? preselectedChildId;
  const AddPointsScreen({super.key, this.preselectedChildId});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen>
    with TickerProviderStateMixin {
  String? _selectedChildId;
  bool _isBonus = true;
  int _points = 1;
  String _reason = '';
  String? _photoBase64;
  bool _isSubmitting = false;
  final _reasonController = TextEditingController();

  // Undo
  String? _lastEntryId;
  bool _showUndo = false;

  late AnimationController _colorAnimController;
  late Animation<Color?> _bgColorAnim;

  final List<String> _bonusQuickReasons = [
    'Devoirs faits', 'Chambre rangée', 'Aide à la maison',
    'Bonne attitude', 'Lecture', 'Politesse', 'Sport', 'Partage',
  ];

  final List<String> _penaltyQuickReasons = [
    'Désobéissance', 'Bagarre', 'Mensonge', 'Cris',
    'Retard', 'Irrespect', 'Désordre', 'Écran sans permission',
  ];

  @override
  void initState() {
    super.initState();
    _selectedChildId = widget.preselectedChildId;
    _colorAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _bgColorAnim = ColorTween(
      begin: Colors.green.withOpacity(0.1),
      end: Colors.red.withOpacity(0.1),
    ).animate(CurvedAnimation(
      parent: _colorAnimController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _colorAnimController.dispose();
    super.dispose();
  }

  void _toggleMode(bool isBonus) {
    setState(() {
      _isBonus = isBonus;
      _reason = '';
      _reasonController.clear();
    });
    if (isBonus) {
      _colorAnimController.reverse();
    } else {
      _colorAnimController.forward();
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 2 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image trop lourde (max 2 Mo)'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      setState(() => _photoBase64 = base64Encode(bytes));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur image: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (_selectedChildId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sélectionne un enfant'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Indique une raison'), backgroundColor: Colors.orange),
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      showPointsAnimation(context, isBonus: _isBonus);
      HapticFeedback.mediumImpact();

      final provider = context.read<FamilyProvider>();
      final points = _isBonus ? _points : -_points;

      await provider.addPoints(
        _selectedChildId!,
        points,
        _reason,
        category: _isBonus ? 'Bonus' : 'Malus',
        emoji: _isBonus ? '⭐' : '⚠️',
        proofPhotoBase64: _photoBase64,
      );

      // Récupérer l'id de la dernière entrée pour le undo
      final history = provider.getHistoryForChild(_selectedChildId!);
      if (history.isNotEmpty) {
        _lastEntryId = history.first.id;
      }

      if (mounted) {
        final child = provider.getChild(_selectedChildId!);
        final childName = child?.name ?? '?';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isBonus
                ? '+$_points points pour $childName !'
                : '-$_points points pour $childName'),
            backgroundColor: _isBonus ? Colors.green : Colors.red,
          ),
        );

        if (_lastEntryId != null) {
          setState(() => _showUndo = true);
          Future.delayed(const Duration(seconds: 8), () {
            if (mounted) setState(() => _showUndo = false);
          });
        }

        setState(() {
          _reason = '';
          _reasonController.clear();
          _photoBase64 = null;
          _points = 1;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _undoLastEntry() async {
    if (_lastEntryId == null) return;
    try {
      final provider = context.read<FamilyProvider>();
      await provider.deleteHistoryEntry(_lastEntryId!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Action annulée !'),
            backgroundColor: Colors.blueGrey,
          ),
        );
        setState(() {
          _showUndo = false;
          _lastEntryId = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur annulation: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final children = provider.sortedChildren;
    final quickReasons = _isBonus ? _bonusQuickReasons : _penaltyQuickReasons;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Ajouter des points'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: AnimatedBackground(
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Bonus / Malus toggle
                    GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: _ToggleButton(
                              label: 'Bonus',
                              icon: Icons.arrow_upward,
                              isSelected: _isBonus,
                              color: Colors.green,
                              onTap: () => _toggleMode(true),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ToggleButton(
                              label: 'Malus',
                              icon: Icons.arrow_downward,
                              isSelected: !_isBonus,
                              color: Colors.red,
                              onTap: () => _toggleMode(false),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Child selector
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Enfant',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          SizedBox(
                            height: 80,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: children.length,
                              itemBuilder: (ctx, i) {
                                final child = children[i];
                                final isSelected = child.id == _selectedChildId;
                                return TvFocusWrapper(
                                  child: GestureDetector(
                                    onTap: () => setState(() => _selectedChildId = child.id),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? (_isBonus ? Colors.green.withOpacity(0.3) : Colors.red.withOpacity(0.3))
                                            : Colors.white.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(16),
                                        border: isSelected
                                            ? Border.all(color: _isBonus ? Colors.green : Colors.red, width: 2)
                                            : null,
                                      ),
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          CircleAvatar(
                                            radius: 18,
                                            backgroundColor: Colors.white24,
                                            backgroundImage: child.photoBase64 != null
                                                ? MemoryImage(base64Decode(child.photoBase64!))
                                                : null,
                                            child: child.photoBase64 == null
                                                ? Text(
                                                    child.name.isNotEmpty ? child.name[0].toUpperCase() : '?',
                                                    style: const TextStyle(color: Colors.white),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            child.name,
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 11,
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick reasons
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Raison rapide',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: quickReasons.map((r) {
                              final isSelected = _reason == r;
                              return TvFocusWrapper(
                                child: ChoiceChip(
                                  label: Text(r),
                                  selected: isSelected,
                                  selectedColor: _isBonus ? Colors.green.withOpacity(0.7) : Colors.red.withOpacity(0.7),
                                  backgroundColor: Colors.white.withOpacity(0.15),
                                  labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.white70),
                                  onSelected: (selected) {
                                    setState(() {
                                      _reason = selected ? r : '';
                                      if (selected) _reasonController.clear();
                                    });
                                  },
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _reasonController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: 'Ou raison personnalisée…',
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.1),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (val) => setState(() => _reason = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Points selector
                    GlassCard(
                      child: Column(
                        children: [
                          Text('Points',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          // Saisie libre
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _PointsButton(
                                icon: Icons.remove,
                                onTap: () { if (_points > 1) setState(() => _points--); },
                              ),
                              const SizedBox(width: 16),
                              SizedBox(
                                width: 80,
                                child: TextField(
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                    color: _isBonus ? Colors.green : Colors.red,
                                  ),
                                  controller: TextEditingController(text: '$_points')
                                    ..selection = TextSelection.collapsed(offset: '$_points'.length),
                                  decoration: const InputDecoration(border: InputBorder.none),
                                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                  onChanged: (v) {
                                    final val = int.tryParse(v);
                                    if (val != null && val > 0) setState(() => _points = val);
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              _PointsButton(
                                icon: Icons.add,
                                onTap: () => setState(() => _points++),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            children: [1, 2, 3, 5, 10].map((v) {
                              return ActionChip(
                                label: Text('$v'),
                                backgroundColor: Colors.white.withOpacity(0.15),
                                labelStyle: const TextStyle(color: Colors.white),
                                onPressed: () => setState(() => _points = v),
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Photo proof
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Photo preuve (optionnel)',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                          const SizedBox(height: 8),
                          if (_photoBase64 != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(base64Decode(_photoBase64!),
                                  height: 150, width: double.infinity, fit: BoxFit.cover),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () => setState(() => _photoBase64 = null),
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              label: const Text('Supprimer', style: TextStyle(color: Colors.redAccent)),
                            ),
                          ] else ...[
                            Row(
                              children: [
                                Expanded(
                                  child: TvFocusWrapper(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickImage(ImageSource.camera),
                                      icon: const Icon(Icons.camera_alt, color: Colors.white70),
                                      label: const Text('Caméra', style: TextStyle(color: Colors.white70)),
                                      style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.white.withOpacity(0.3))),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TvFocusWrapper(
                                    child: OutlinedButton.icon(
                                      onPressed: () => _pickImage(ImageSource.gallery),
                                      icon: const Icon(Icons.photo_library, color: Colors.white70),
                                      label: const Text('Galerie', style: TextStyle(color: Colors.white70)),
                                      style: OutlinedButton.styleFrom(
                                          side: BorderSide(color: Colors.white.withOpacity(0.3))),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Submit
                    TvFocusWrapper(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isBonus ? Colors.green : Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(width: 24, height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text(
                                _isBonus ? 'Ajouter le bonus' : 'Appliquer le malus',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                    const SizedBox(height: 80),
                  ],
                ),
              ),

              // Undo button
              if (_showUndo)
                Positioned(
                  bottom: 16,
                  left: 16,
                  right: 16,
                  child: TvFocusWrapper(
                    child: ElevatedButton.icon(
                      onPressed: _undoLastEntry,
                      icon: const Icon(Icons.undo),
                      label: const Text('Annuler la dernière action'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==================== HELPER WIDGETS ====================

class _ToggleButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return TvFocusWrapper(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.3) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? color : Colors.white24, width: isSelected ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: isSelected ? color : Colors.white54),
              const SizedBox(width: 8),
              Text(label,
                  style: TextStyle(
                      color: isSelected ? color : Colors.white54,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PointsButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _PointsButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TvFocusWrapper(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(icon, color: Colors.white),
        ),
      ),
    );
  }
}
