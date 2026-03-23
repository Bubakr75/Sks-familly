import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/family_provider.dart';
import '../widgets/confetti_widget.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';

class AddPointsScreen extends StatefulWidget {
  const AddPointsScreen({super.key});

  @override
  State<AddPointsScreen> createState() => _AddPointsScreenState();
}

class _AddPointsScreenState extends State<AddPointsScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  String? _selectedChildId;
  int _points = 5;
  bool _isBonus = true;
  String _reason = '';
  String _category = 'Bonus';
  final _reasonController = TextEditingController();
  bool _showConfetti = false;
  late AnimationController _submitAnim;

  File? _proofPhoto;
  String? _proofPhotoBase64;
  final ImagePicker _picker = ImagePicker();

  final _bonusCategories = [
    {'name': 'Bon comportement', 'icon': Icons.thumb_up_rounded, 'points': 5, 'emoji': '\u{1F44D}'},
    {'name': 'Fait ses devoirs', 'icon': Icons.school_rounded, 'points': 10, 'emoji': '\u{1F4DA}'},
    {'name': 'Actes fraternels', 'icon': Icons.favorite_rounded, 'points': 5, 'emoji': '\u{2764}'},
    {'name': 'Aide a la maison', 'icon': Icons.home_rounded, 'points': 10, 'emoji': '\u{1F3E0}'},
    {'name': 'Rangement', 'icon': Icons.cleaning_services_rounded, 'points': 5, 'emoji': '\u{1F9F9}'},
    {'name': 'Politesse', 'icon': Icons.emoji_people_rounded, 'points': 3, 'emoji': '\u{1F64F}'},
    {'name': 'Sport / Activite', 'icon': Icons.sports_soccer_rounded, 'points': 8, 'emoji': '\u{26BD}'},
    {'name': 'Creativite', 'icon': Icons.palette_rounded, 'points': 5, 'emoji': '\u{1F3A8}'},
  ];

  final _penalityCategories = [
    {'name': 'Mauvais comportement', 'icon': Icons.thumb_down_rounded, 'points': -5, 'emoji': '\u{1F44E}'},
    {'name': 'Desobeissance', 'icon': Icons.block_rounded, 'points': -10, 'emoji': '\u{1F6AB}'},
    {'name': 'Dispute', 'icon': Icons.warning_rounded, 'points': -5, 'emoji': '\u{26A0}'},
    {'name': 'Mensonge', 'icon': Icons.visibility_off_rounded, 'points': -10, 'emoji': '\u{1F648}'},
    {'name': 'Impolitesse', 'icon': Icons.sentiment_dissatisfied_rounded, 'points': -3, 'emoji': '\u{1F621}'},
    {'name': 'Ecran abusif', 'icon': Icons.phone_android_rounded, 'points': -5, 'emoji': '\u{1F4F1}'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _submitAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden) {
      _submitAnim.stop();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reasonController.dispose();
    _submitAnim.dispose();
    super.dispose();
  }

  Future<void> _pickProofPhoto(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 70,
      );
      if (picked != null) {
        final file = File(picked.path);
        final bytes = await file.readAsBytes();
        setState(() {
          _proofPhoto = file;
          _proofPhotoBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('Erreur lors de la selection de la photo'),
              ],
            ),
            backgroundColor: const Color(0xFFFF1744),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _showPhotoSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF1A1A2E)
              : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: const Color(0xFFFF1744).withValues(alpha: 0.3),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Photo preuve',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFFF1744)),
            ),
            const SizedBox(height: 4),
            Text(
              'Ajoutez une preuve visuelle pour cette penalite',
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildPhotoOption(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  color: const Color(0xFF00B0FF),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProofPhoto(ImageSource.camera);
                  },
                ),
                _buildPhotoOption(
                  icon: Icons.photo_library_rounded,
                  label: 'Galerie',
                  color: const Color(0xFF00E676),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickProofPhoto(ImageSource.gallery);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: isDark ? 0.15 : 0.1),
              border: Border.all(color: color.withValues(alpha: 0.3)),
              boxShadow: isDark
                  ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12)]
                  : null,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Consumer<FamilyProvider>(
      builder: (context, provider, _) {
        if (provider.children.isEmpty) {
          return AnimatedBackground(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GlowIcon(
                      icon: Icons.person_add_rounded,
                      size: 64,
                      color: Colors.grey[600]),
                  const SizedBox(height: 16),
                  NeonText(
                      text: 'Ajoutez des enfants d\'abord',
                      fontSize: 16,
                      color: Colors.grey),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: Colors.transparent,
          body: AnimatedBackground(
            child: Stack(
              children: [
                SafeArea(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Titre ──
                        Row(
                          children: [
                            GlowIcon(
                              icon: _isBonus
                                  ? Icons.add_circle_rounded
                                  : Icons.remove_circle_rounded,
                              color: _isBonus
                                  ? const Color(0xFF00E676)
                                  : const Color(0xFFFF1744),
                              size: 28,
                            ),
                            const SizedBox(width: 10),
                            NeonText(
                              text: 'Ajouter des points',
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              glowIntensity: 0.2,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Sélection enfant ──
                        NeonText(
                            text: 'Choisir un enfant',
                            fontSize: 14,
                            color: Colors.white70,
                            glowIntensity: 0.1),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 96,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: provider.children.length,
                            itemBuilder: (context, index) {
                              final c = provider.children[index];
                              final isSelected = _selectedChildId == c.id;
                              return GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedChildId = c.id),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 250),
                                  width: 80,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? primary.withValues(alpha: 0.15)
                                        : Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? primary
                                          : Colors.white
                                              .withValues(alpha: 0.08),
                                      width: isSelected ? 2 : 1,
                                    ),
                                    boxShadow: isSelected
                                        ? [
                                            BoxShadow(
                                                color: primary
                                                    .withValues(alpha: 0.2),
                                                blurRadius: 12)
                                          ]
                                        : null,
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                          c.avatar.isEmpty
                                              ? '\u{1F466}'
                                              : c.avatar,
                                          style:
                                              const TextStyle(fontSize: 28)),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        width: 68,
                                        child: Text(
                                          c.name,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: isSelected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: isSelected
                                                ? primary
                                                : Colors.white70,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 20),

                        // ── Bonus / Pénalité ──
                        Row(
                          children: [
                            Expanded(
                                child: _buildToggle(
                                    'Bonus',
                                    Icons.add_circle_rounded,
                                    const Color(0xFF00E676),
                                    _isBonus,
                                    () => setState(() {
                                          _isBonus = true;
                                          _category = 'Bonus';
                                          _proofPhoto = null;
                                          _proofPhotoBase64 = null;
                                        }))),
                            const SizedBox(width: 12),
                            Expanded(
                                child: _buildToggle(
                                    'Penalite',
                                    Icons.remove_circle_rounded,
                                    const Color(0xFFFF1744),
                                    !_isBonus,
                                    () => setState(() {
                                          _isBonus = false;
                                          _category = 'Penalite';
                                        }))),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // ── Raisons rapides ──
                        NeonText(
                            text: 'Raison rapide',
                            fontSize: 14,
                            color: Colors.white70,
                            glowIntensity: 0.1),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: (_isBonus
                                  ? _bonusCategories
                                  : _penalityCategories)
                              .map((cat) {
                            final isActive =
                                _reason == (cat['name'] as String);
                            final chipColor = _isBonus
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF1744);
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  _reason = cat['name'] as String;
                                  _points = (cat['points'] as int).abs();
                                  _reasonController.text = _reason;
                                });
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: isActive
                                      ? chipColor.withValues(alpha: 0.15)
                                      : Colors.white.withValues(alpha: 0.04),
                                  border: Border.all(
                                    color: isActive
                                        ? chipColor.withValues(alpha: 0.5)
                                        : Colors.white
                                            .withValues(alpha: 0.08),
                                    width: isActive ? 1.5 : 1,
                                  ),
                                  boxShadow: isActive
                                      ? [
                                          BoxShadow(
                                              color: chipColor
                                                  .withValues(alpha: 0.15),
                                              blurRadius: 8)
                                        ]
                                      : null,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(cat['emoji'] as String,
                                        style: const TextStyle(fontSize: 16)),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat['name'] as String,
                                      style: TextStyle(
                                        fontWeight: isActive
                                            ? FontWeight.bold
                                            : FontWeight.w500,
                                        fontSize: 13,
                                        color: isActive
                                            ? chipColor
                                            : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 16),

                        // ── Raison personnalisée ──
                        TextField(
                          controller: _reasonController,
                          style: const TextStyle(color: Colors.white),
                          decoration: InputDecoration(
                            labelText: 'Raison personnalisee',
                            prefixIcon: GlowIcon(
                                icon: Icons.edit_rounded,
                                size: 20,
                                color: primary),
                          ),
                          onChanged: (v) => _reason = v,
                        ),
                        const SizedBox(height: 24),

                        // ── Photo preuve (pénalité uniquement) ──
                        if (!_isBonus) ...[
                          NeonText(
                            text: 'Photo preuve (optionnel)',
                            fontSize: 14,
                            color: Colors.white70,
                            glowIntensity: 0.1,
                          ),
                          const SizedBox(height: 10),
                          _buildProofPhotoSection(isDark),
                          const SizedBox(height: 24),
                        ],

                        // ── Nombre de points ──
                        NeonText(
                            text: 'Nombre de points',
                            fontSize: 14,
                            color: Colors.white70,
                            glowIntensity: 0.1),
                        const SizedBox(height: 12),
                        GlassCard(
                          margin: EdgeInsets.zero,
                          padding: const EdgeInsets.symmetric(
                              vertical: 20, horizontal: 16),
                          borderRadius: 20,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildPointButton(
                                  Icons.remove_circle_rounded,
                                  const Color(0xFFFF1744), () {
                                if (_points > 1) setState(() => _points--);
                              }),
                              const SizedBox(width: 20),
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(
                                        scale: anim, child: child),
                                child: Container(
                                  key: ValueKey('${_isBonus}_$_points'),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 28, vertical: 14),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: (_isBonus
                                            ? const Color(0xFF00E676)
                                            : const Color(0xFFFF1744))
                                        .withValues(alpha: 0.1),
                                    border: Border.all(
                                      color: (_isBonus
                                              ? const Color(0xFF00E676)
                                              : const Color(0xFFFF1744))
                                          .withValues(alpha: 0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: (_isBonus
                                                ? const Color(0xFF00E676)
                                                : const Color(0xFFFF1744))
                                            .withValues(alpha: 0.2),
                                        blurRadius: 16,
                                      ),
                                    ],
                                  ),
                                  child: NeonText(
                                    text:
                                        '${_isBonus ? '+' : '-'}$_points',
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: _isBonus
                                        ? const Color(0xFF00E676)
                                        : const Color(0xFFFF1744),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 20),
                              _buildPointButton(
                                  Icons.add_circle_rounded,
                                  const Color(0xFF00E676), () {
                                setState(() => _points++);
                              }),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // ── Raccourcis points ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [1, 3, 5, 10, 20, 50].map((v) {
                            final isSelected = _points == v;
                            final color = _isBonus
                                ? const Color(0xFF00E676)
                                : const Color(0xFFFF1744);
                            return Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 3),
                              child: GestureDetector(
                                onTap: () => setState(() => _points = v),
                                child: AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: isSelected
                                        ? color.withValues(alpha: 0.15)
                                        : Colors.white
                                            .withValues(alpha: 0.04),
                                    border: Border.all(
                                      color: isSelected
                                          ? color.withValues(alpha: 0.5)
                                          : Colors.white
                                              .withValues(alpha: 0.08),
                                    ),
                                  ),
                                  child: Text(
                                    '$v',
                                    style: TextStyle(
                                      color: isSelected
                                          ? color
                                          : Colors.white54,
                                      fontWeight: isSelected
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 28),

                        // ── Bouton valider ──
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: _selectedChildId != null &&
                                      _reason.isNotEmpty
                                  ? [
                                      BoxShadow(
                                        color: (_isBonus
                                                ? const Color(0xFF00E676)
                                                : const Color(0xFFFF1744))
                                            .withValues(alpha: 0.3),
                                        blurRadius: 16,
                                        spreadRadius: -2,
                                      ),
                                    ]
                                  : null,
                            ),
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: _isBonus
                                    ? const Color(0xFF00C853)
                                    : const Color(0xFFD50000),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(18)),
                              ),
                              onPressed: _selectedChildId == null ||
                                      _reason.isEmpty
                                  ? null
                                  : () => _submitPoints(provider),
                              icon: Icon(_isBonus
                                  ? Icons.check_circle_rounded
                                  : Icons.gavel_rounded),
                              label: Text(
                                _isBonus
                                    ? 'Attribuer +$_points points'
                                    : 'Retirer -$_points points',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 16),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ── Confettis ──
                if (_showConfetti)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ConfettiWidget(
                          onComplete: () =>
                              setState(() => _showConfetti = false)),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Photo preuve ──
  Widget _buildProofPhotoSection(bool isDark) {
    if (_proofPhoto != null) {
      return GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.all(12),
        borderRadius: 18,
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                children: [
                  Image.file(
                    _proofPhoto!,
                    width: double.infinity,
                    height: 200,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.6),
                          ],
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      child: const Row(
                        children: [
                          Icon(Icons.camera_alt_rounded,
                              color: Colors.white70, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Photo preuve jointe',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _showPhotoSourceDialog,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Changer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00B0FF),
                      side: const BorderSide(
                          color: Color(0xFF00B0FF), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        _proofPhoto = null;
                        _proofPhotoBase64 = null;
                      });
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    label: const Text('Supprimer'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFFF1744),
                      side: const BorderSide(
                          color: Color(0xFFFF1744), width: 1),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: _showPhotoSourceDialog,
      child: GlassCard(
        margin: EdgeInsets.zero,
        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
        borderRadius: 18,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFF1744).withValues(alpha: 0.1),
                border: Border.all(
                    color: const Color(0xFFFF1744).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.add_a_photo_rounded,
                  color: Color(0xFFFF1744), size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Ajouter une photo preuve',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFFF1744),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Camera ou galerie',
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[600], size: 24),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════
  // ── CORRIGÉ : category et proofPhotoBase64 en paramètres nommés ──
  // ══════════════════════════════════════════════════════════
  void _submitPoints(FamilyProvider provider) {
    final pts = _isBonus ? _points : -_points;

    provider.addPoints(
      _selectedChildId!,
      pts,
      _reason,
      category: _category,
      isBonus: _isBonus,
      proofPhotoBase64: _proofPhotoBase64,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isBonus
                  ? Icons.check_circle_rounded
                  : Icons.gavel_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_isBonus ? '+' : ''}$pts points pour ${provider.getChild(_selectedChildId!)?.name}'
                '${_proofPhotoBase64 != null ? ' (avec photo)' : ''}',
              ),
            ),
          ],
        ),
        backgroundColor:
            _isBonus ? const Color(0xFF00C853) : const Color(0xFFD50000),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );

    if (_isBonus) setState(() => _showConfetti = true);

    setState(() {
      _reason = '';
      _reasonController.clear();
      _points = 5;
      _proofPhoto = null;
      _proofPhotoBase64 = null;
    });
  }

  // ── Toggle Bonus/Pénalité ──
  Widget _buildToggle(
      String label, IconData icon, Color color, bool active, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: active
              ? color.withValues(alpha: isDark ? 0.15 : 0.1)
              : Colors.white.withValues(alpha: 0.04),
          border: Border.all(
            color: active
                ? color.withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.08),
            width: active ? 2 : 1,
          ),
          boxShadow: active && isDark
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 12)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: active ? color : Colors.grey, size: 22),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                color: active ? color : Colors.grey,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Bouton +/- points ──
  Widget _buildPointButton(IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: isDark ? 0.12 : 0.08),
          border: Border.all(color: color.withValues(alpha: 0.3)),
          boxShadow: isDark
              ? [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 8)]
              : null,
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
