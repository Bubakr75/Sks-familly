import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import '../widgets/family_join_panel.dart';
import '../widgets/family_join_approval_panel.dart';
import '../widgets/tv_focus_wrapper.dart';
import 'account_security_screen.dart';
import 'family_managers_screen.dart';
import 'family_ownership_screen.dart';
import 'firebase_diagnostic_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool _isLoading = false;
  String? _familyCode;
  bool _isFamilyCodeVisible = false;
  final _customCodeController = TextEditingController();
  bool _useCustomCode = false;

  final _customCodeFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFamilyCode();
  }

  Future<void> _loadFamilyCode() async {
    final provider = context.read<FamilyProvider>();
    if (provider.isSyncEnabled) {
      try {
        await provider.refreshFamilyAccessContext();
      } catch (_) {
        // Le code reste masqué si le serveur ne confirme pas l'autorisation.
      }
    }
    final code = provider.getFamilyCode();
    if (mounted) setState(() => _familyCode = code.isNotEmpty ? code : null);
  }

  @override
  void dispose() {
    _customCodeController.dispose();
    _customCodeFocusNode.dispose();
    super.dispose();
  }

  // ─── Créer une famille ──────────────────────────────────────
  Future<void> _createFamily() async {
    String? customCode;
    if (_useCustomCode) {
      customCode = _customCodeController.text.trim().toUpperCase();
      if (customCode.length < 4) {
        _showSnack('Le code doit avoir au moins 4 caractères.', isError: true);
        return;
      }
      if (customCode.length > 10) {
        _showSnack('Le code ne doit pas dépasser 10 caractères.',
            isError: true);
        return;
      }
      if (!RegExp(r'^[A-Z0-9]+$').hasMatch(customCode)) {
        _showSnack('Uniquement des lettres et des chiffres.', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final code = await context
          .read<FamilyProvider>()
          .createFamily(customCode: customCode);
      if (!mounted) return;
      setState(() {
        _familyCode = code;
        _isLoading = false;
      });
      _showSnack('🎉 Famille créée ! Code : $code');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Erreur : $e', isError: true);
    }
  }

  // ─── Se déconnecter ─────────────────────────────────────────
  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Se déconnecter ?'),
          ],
        ),
        content: const Text(
            'Les données locales seront conservées.\nLes autres appareils resteront connectés.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await context.read<FamilyProvider>().disconnectFamily();
      if (!mounted) return;
      setState(() {
        _familyCode = null;
        _useCustomCode = false;
      });
      _showSnack('Déconnecté. Données locales conservées.');
    }
  }

  // ─── Copier le code ─────────────────────────────────────────
  void _copyCode() {
    if (_familyCode == null) return;
    Clipboard.setData(ClipboardData(text: _familyCode!));
    _showSnack('Code "$_familyCode" copié dans le presse-papier ! 📋');
  }

  // ─── Changer le code ────────────────────────────────────────
  Future<void> _showLegacyMigrationDialog() async {
    final controller = TextEditingController();

    final secret = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Expanded(child: Text('Sécuriser l’ancienne famille')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Saisissez le code temporaire de migration fourni par '
              'l’administrateur. Il ne sera pas enregistré sur l’appareil.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Code temporaire',
                prefixIcon: Icon(Icons.key_rounded),
              ),
              onSubmitted: (value) {
                final cleanValue = value.trim();
                if (cleanValue.isNotEmpty) {
                  Navigator.pop(ctx, cleanValue);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton.icon(
            onPressed: () {
              final cleanValue = controller.text.trim();
              if (cleanValue.isNotEmpty) {
                Navigator.pop(ctx, cleanValue);
              }
            },
            icon: const Icon(Icons.verified_user_rounded),
            label: const Text('Migrer'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (secret == null || secret.isEmpty || !mounted) return;

    setState(() => _isLoading = true);

    try {
      final newCode =
          await context.read<FamilyProvider>().migrateLegacyFamily(secret);

      if (!mounted) return;

      setState(() {
        _familyCode = newCode;
        _isLoading = false;
      });

      _showSnack(
        'Famille sécurisée. Le nouveau code est $newCode.',
      );
    } catch (error) {
      if (!mounted) return;

      setState(() => _isLoading = false);
      _showSnack('Migration impossible : $error', isError: true);
    }
  }

  Future<void> _showChangeCodeDialog() async {
    final controller = TextEditingController(text: _familyCode);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.edit_rounded, color: Colors.blue),
            SizedBox(width: 8),
            Text('Modifier le code famille'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '⚠️ Les autres appareils devront utiliser le nouveau code pour rejoindre.',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              textCapitalization: TextCapitalization.characters,
              textAlign: TextAlign.center,
              maxLength: 10,
              autofocus: true,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
              ),
              decoration: const InputDecoration(
                hintText: 'NOUVEAU CODE',
                counterText: '',
                helperText: '4 à 10 caractères alphanumériques',
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () {
              final newCode = controller.text.trim().toUpperCase();
              if (newCode.length < 4) return; // validation simple
              Navigator.pop(ctx, newCode);
            },
            child: const Text('Valider'),
          ),
        ],
      ),
    ).then((v) {
      controller.dispose();
      return v;
    });

    if (result == null || result.isEmpty || result == _familyCode) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      await context.read<FamilyProvider>().changeFamilyCode(result);
      if (!mounted) return;
      setState(() {
        _familyCode = result;
        _isLoading = false;
      });
      _showSnack('✅ Code changé en "$result" !');
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      _showSnack('Erreur : $e', isError: true);
    }
  }

  // ─── Snackbar helper ────────────────────────────────────────
  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor:
          isError ? const Color(0xFFFF1744) : const Color(0xFF00C853),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  // ─── TextField TV-compatible ────────────────────────────────
  Widget _buildTvTextField({
    required TextEditingController controller,
    required FocusNode focusNode,
    String? hintText,
    int? maxLength,
    TextInputType? keyboardType,
    bool obscureText = false,
    TextCapitalization textCapitalization = TextCapitalization.none,
    List<TextInputFormatter>? inputFormatters,
    Widget? suffixIcon,
    String? helperText,
    VoidCallback? onSubmitted,
  }) {
    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: (event) {
        if (event is KeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
            focusNode.nextFocus();
          } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
            focusNode.previousFocus();
          }
        }
      },
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textCapitalization: textCapitalization,
        textAlign: TextAlign.center,
        maxLength: maxLength,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 4,
        ),
        decoration: InputDecoration(
          hintText: hintText,
          counterText: '',
          helperText: helperText,
          suffixIcon: suffixIcon,
        ),
        inputFormatters: inputFormatters,
        onSubmitted: (_) =>
            onSubmitted != null ? onSubmitted() : focusNode.nextFocus(),
      ),
    );
  }

  // ─── BUILD ──────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final isConnected = provider.isSyncEnabled;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AnimatedBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 16),
                      Text(
                        'Connexion en cours...',
                        style: TextStyle(
                          fontSize: 16,
                          color: primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ─── Header ───────────────────────────
                      Row(
                        children: [
                          TvFocusWrapper(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.08),
                                ),
                              ),
                              child: const Icon(
                                Icons.arrow_back_rounded,
                                color: Colors.white70,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Icon(Icons.cloud_sync_rounded,
                              color: primary, size: 26),
                          const SizedBox(width: 10),
                          Text(
                            'Synchronisation',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                          ),
                          const Spacer(),
                          TvFocusWrapper(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AccountSecurityScreen(),
                              ),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(
                                Icons.verified_user_rounded,
                                color: primary,
                                size: 18,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          TvFocusWrapper(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    const FirebaseDiagnosticScreen(),
                              ),
                            ),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(Icons.bug_report_rounded,
                                  color: primary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // ─── Statut de connexion ───────────────
                      GlassCard(
                        padding: const EdgeInsets.all(20),
                        borderRadius: 20,
                        glowColor: isConnected ? const Color(0xFF00E676) : null,
                        child: Row(
                          children: [
                            Container(
                              width: 56,
                              height: 56,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: (isConnected
                                        ? const Color(0xFF00E676)
                                        : Colors.grey)
                                    .withValues(alpha: 0.12),
                                boxShadow: isConnected
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF00E676)
                                              .withValues(alpha: 0.2),
                                          blurRadius: 12,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                isConnected
                                    ? Icons.cloud_done_rounded
                                    : Icons.cloud_off_rounded,
                                color: isConnected
                                    ? const Color(0xFF00E676)
                                    : Colors.grey,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isConnected
                                        ? 'Synchronisé ✅'
                                        : 'Mode local',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      color: isConnected
                                          ? const Color(0xFF00E676)
                                          : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isConnected
                                        ? 'Données partagées en temps réel'
                                        : 'Les données restent sur cet appareil',
                                    style: TextStyle(
                                        color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // ─── Vue connectée ou non ──────────────
                      if (isConnected) ...[
                        _buildConnectedView(primary),
                        if (provider.memberRole == 'owner' ||
                            provider.memberRole == 'manager' ||
                            provider.memberRole == 'familyAdmin') ...[
                          const SizedBox(height: 20),
                          FamilyJoinApprovalPanel(
                            familyId: provider.familyId!,
                          ),
                        ],
                      ] else ...[
                        _buildCreateSection(primary),
                        const SizedBox(height: 20),
                        _buildJoinSection(),
                      ],

                      const SizedBox(height: 24),
                      _buildInfoCard(primary),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ─── Vue connectée ──────────────────────────────────────────
  Widget _buildConnectedView(Color primary) {
    final role = context.read<FamilyProvider>().memberRole;
    final canManageCode =
        role == 'owner' || role == 'manager' || role == 'familyAdmin';

    if (!canManageCode) {
      final message = role == 'child'
          ? 'Le code familial n’est pas accessible depuis un profil enfant.'
          : 'Code masqué — réservé au propriétaire ou gestionnaire';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _neonLabel('Code famille', primary),
          const SizedBox(height: 8),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 20,
            glowColor: primary,
            child: Column(
              children: [
                const Icon(Icons.lock_rounded, size: 38),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off_rounded),
                  label: const Text('Se déconnecter'),
                ),
              ],
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _neonLabel('Code famille', primary),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          glowColor: primary,
          child: Column(
            children: [
              const Text(
                'Partagez ce code avec votre conjoint(e) :',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.white70),
              ),
              const SizedBox(height: 16),

              // Affichage du code
              TvFocusWrapper(
                onTap: _isFamilyCodeVisible ? _copyCode : null,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                        color: primary.withValues(alpha: 0.3), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: primary.withValues(alpha: 0.15),
                          blurRadius: 16),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        _familyCode == null
                            ? 'Code indisponible'
                            : _isFamilyCodeVisible
                                ? _familyCode!
                                : '••••••',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: primary,
                          shadows: [
                            Shadow(
                                color: primary.withValues(alpha: 0.5),
                                blurRadius: 12),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _familyCode == null
                            ? 'Réessayez après avoir vérifié la connexion'
                            : _isFamilyCodeVisible
                                ? 'Appuyez pour copier'
                                : 'Code masqué',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Boutons d'action
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _familyCode == null
                      ? null
                      : () {
                          setState(() {
                            _isFamilyCodeVisible = !_isFamilyCodeVisible;
                          });
                        },
                  icon: Icon(
                    _isFamilyCodeVisible
                        ? Icons.visibility_off_rounded
                        : Icons.visibility_rounded,
                  ),
                  label: Text(
                    _isFamilyCodeVisible
                        ? 'Masquer le code'
                        : 'Afficher le code',
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isFamilyCodeVisible && _familyCode != null
                      ? _copyCode
                      : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copier le code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (context.read<FamilyProvider>().memberRole == 'owner') ...[
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyManagersScreen(
                          familyId: context.read<FamilyProvider>().familyId!,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.admin_panel_settings_rounded),
                    label: const Text('Gérer les gestionnaires'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => FamilyOwnershipScreen(
                          familyId: context.read<FamilyProvider>().familyId!,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.swap_horiz_rounded),
                    label: const Text('Propriété et récupération'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showChangeCodeDialog,
                  icon: const Icon(Icons.edit_rounded),
                  label: const Text('Modifier le code'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _showLegacyMigrationDialog,
                  icon: const Icon(
                    Icons.security_rounded,
                    color: Colors.orange,
                  ),
                  label: const Text(
                    'Sécuriser une ancienne famille',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon:
                      const Icon(Icons.link_off_rounded, color: Colors.orange),
                  label: const Text(
                    'Se déconnecter',
                    style: TextStyle(color: Colors.orange),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section créer ──────────────────────────────────────────
  Widget _buildCreateSection(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _neonLabel('Créer une famille', primary),
        const SizedBox(height: 8),
        GlassCard(
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.12),
                  boxShadow: [
                    BoxShadow(
                        color: primary.withValues(alpha: 0.15), blurRadius: 12),
                  ],
                ),
                child: Icon(Icons.group_add_rounded, color: primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Créez une famille et obtenez un code à partager.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Code personnalisé',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                  Switch(
                    value: _useCustomCode,
                    onChanged: (v) => setState(() => _useCustomCode = v),
                  ),
                ],
              ),
              if (_useCustomCode) ...[
                const SizedBox(height: 8),
                _buildTvTextField(
                  controller: _customCodeController,
                  focusNode: _customCodeFocusNode,
                  hintText: 'Ex: SKS2025',
                  maxLength: 10,
                  textCapitalization: TextCapitalization.characters,
                  helperText: '4 à 10 caractères alphanumériques',
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                  ],
                  onSubmitted: _createFamily,
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createFamily,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(
                    _useCustomCode ? 'Créer avec mon code' : 'Créer ma famille',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ─── Section rejoindre ──────────────────────────────────────
  Widget _buildJoinSection() {
    return FamilyJoinPanel(
      onActivated: ({
        required familyId,
        required familyCode,
        required role,
        childId,
      }) async {
        await context.read<FamilyProvider>().finalizeApprovedFamily(
              familyId: familyId,
              familyCode: familyCode,
              role: role,
              childId: childId,
            );
        if (!mounted) return;
        setState(() {
          _familyCode = context.read<FamilyProvider>().familyCode;
        });
        _showSnack('Connexion autorisée, famille chargée.');
      },
    );
  }

  // ─── Carte info ─────────────────────────────────────────────
  Widget _buildInfoCard(Color primary) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              Text(
                'Comment ça marche ?',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            (Icons.looks_one_rounded, 'Un parent crée la famille'),
            (Icons.looks_two_rounded, 'Il copie et partage le code'),
            (Icons.looks_3_rounded, 'L\'autre parent colle le code'),
            (
              Icons.looks_4_rounded,
              'Les données se synchronisent en temps réel !'
            ),
          ].map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(item.$1, size: 20, color: primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item.$2,
                        style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ─── Label néon ─────────────────────────────────────────────
  Widget _neonLabel(String text, Color color) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
        shadows: [Shadow(color: color.withValues(alpha: 0.3), blurRadius: 8)],
      ),
    );
  }
}
