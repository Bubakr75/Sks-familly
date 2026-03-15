import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/family_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/animated_background.dart';
import 'firebase_diagnostic_screen.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});
  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  bool _isLoading = false;
  String? _familyCode;
  final _joinController = TextEditingController();
  final _customCodeController = TextEditingController();
  bool _useCustomCode = false;

  @override
  void initState() {
    super.initState();
    _loadFamilyCode();
  }

  Future<void> _loadFamilyCode() async {
    final provider = context.read<FamilyProvider>();
    final code = await provider.getFamilyCode();
    if (mounted) setState(() => _familyCode = code);
  }

  @override
  void dispose() {
    _joinController.dispose();
    _customCodeController.dispose();
    super.dispose();
  }

  Future<void> _createFamily() async {
    String? customCode;
    if (_useCustomCode) {
      customCode = _customCodeController.text.trim().toUpperCase();
      if (customCode.length < 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le code doit avoir au moins 4 caracteres'), backgroundColor: Colors.orange),
        );
        return;
      }
      if (customCode.length > 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Le code ne doit pas depasser 10 caracteres'), backgroundColor: Colors.orange),
        );
        return;
      }
    }

    setState(() => _isLoading = true);
    try {
      final provider = context.read<FamilyProvider>();
      final code = await provider.createFamily(customCode: customCode);
      if (!mounted) return;
      setState(() { _familyCode = code; _isLoading = false; });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Famille creee ! Code : $code'), backgroundColor: const Color(0xFF00C853)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e'), backgroundColor: const Color(0xFFFF1744)),
      );
    }
  }

  Future<void> _joinFamily() async {
    final code = _joinController.text.trim().toUpperCase();
    if (code.isEmpty || code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Entrez le code famille (4 a 10 caracteres)'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final provider = context.read<FamilyProvider>();
      final success = await provider.joinFamily(code);
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (success) {
        setState(() => _familyCode = code);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Connecte a la famille !'), backgroundColor: Color(0xFF00C853)),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Code non trouve'), backgroundColor: Color(0xFFFF1744)),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF0D1B2A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Row(
            children: [
              Icon(Icons.error, color: Color(0xFFFF1744)),
              SizedBox(width: 8),
              Text('Erreur Firebase', style: TextStyle(color: Colors.white)),
            ],
          ),
          content: Text('$e', style: const TextStyle(color: Colors.white70, fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.push(context, MaterialPageRoute(builder: (_) => const FirebaseDiagnosticScreen()));
              },
              child: const Text('Diagnostic'),
            ),
            FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
    }
  }

  Future<void> _disconnect() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0D1B2A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 8),
            Text('Deconnecter', style: TextStyle(color: Colors.white)),
          ],
        ),
        content: const Text('Les donnees locales seront conservees. Continuer ?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Deconnecter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      await context.read<FamilyProvider>().disconnectFamily();
      if (!mounted) return;
      setState(() { _familyCode = null; _useCustomCode = false; });
    }
  }

  void _copyCode() {
    if (_familyCode == null) return;
    Clipboard.setData(ClipboardData(text: _familyCode!));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code "$_familyCode" copie !'), backgroundColor: const Color(0xFF00C853)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FamilyProvider>();
    final isConnected = provider.isSyncEnabled;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      body: AnimatedBackground(
        child: SafeArea(
          child: _isLoading
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(color: primary),
                      const SizedBox(height: 16),
                      NeonText(text: 'Connexion en cours...', fontSize: 16, color: primary),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pop(context),
                            child: Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white.withValues(alpha: 0.06),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: const Icon(Icons.arrow_back_rounded, color: Colors.white70, size: 20),
                            ),
                          ),
                          const SizedBox(width: 14),
                          GlowIcon(icon: Icons.cloud_sync_rounded, color: primary, size: 26),
                          const SizedBox(width: 10),
                          NeonText(text: 'Synchronisation', fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white, glowIntensity: 0.2),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FirebaseDiagnosticScreen())),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.06),
                              ),
                              child: Icon(Icons.bug_report_rounded, color: primary, size: 18),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Status card
                      GlassCard(
                        margin: EdgeInsets.zero,
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
                                color: (isConnected ? const Color(0xFF00E676) : Colors.grey).withValues(alpha: 0.12),
                                boxShadow: isConnected
                                    ? [BoxShadow(color: const Color(0xFF00E676).withValues(alpha: 0.2), blurRadius: 12)]
                                    : null,
                              ),
                              child: Icon(
                                isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                                color: isConnected ? const Color(0xFF00E676) : Colors.grey,
                                size: 28,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  NeonText(
                                    text: isConnected ? 'Synchronise' : 'Mode local',
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: isConnected ? const Color(0xFF00E676) : Colors.grey,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    isConnected ? 'Donnees partagees en temps reel' : 'Les donnees restent sur cet appareil',
                                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (isConnected)
                        _buildConnectedView(primary)
                      else ...[
                        _buildCreateSection(primary),
                        const SizedBox(height: 20),
                        _buildJoinSection(primary),
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

  Widget _buildConnectedView(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(text: 'Code famille', fontSize: 13, fontWeight: FontWeight.w700, color: primary, glowIntensity: 0.3),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          glowColor: primary,
          child: Column(
            children: [
              const Text('Partagez ce code avec votre conjoint(e) :', textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Colors.white70)),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: _copyCode,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: primary.withValues(alpha: 0.3), width: 2),
                    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 16)],
                  ),
                  child: Column(
                    children: [
                      NeonText(text: _familyCode ?? '...', fontSize: 36, fontWeight: FontWeight.w900, color: primary),
                      const SizedBox(height: 6),
                      Text('Appuyez pour copier', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _copyCode,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Copier le code'),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _disconnect,
                  icon: const Icon(Icons.link_off_rounded, color: Colors.orange),
                  label: const Text('Deconnecter', style: TextStyle(color: Colors.orange)),
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

  Widget _buildCreateSection(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(text: 'Creer une famille', fontSize: 13, fontWeight: FontWeight.w700, color: primary, glowIntensity: 0.3),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primary.withValues(alpha: 0.12),
                  boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 12)],
                ),
                child: Icon(Icons.group_add_rounded, color: primary, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Creez une famille et obtenez un code.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text('Code personnalise', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  ),
                  Switch(
                    value: _useCustomCode,
                    onChanged: (v) => setState(() => _useCustomCode = v),
                  ),
                ],
              ),
              if (_useCustomCode) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _customCodeController,
                  textCapitalization: TextCapitalization.characters,
                  textAlign: TextAlign.center,
                  maxLength: 10,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Ex: SKS2025',
                    counterText: '',
                    helperText: '4 a 10 caracteres',
                    helperStyle: TextStyle(color: Colors.grey[600]),
                  ),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _createFamily,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(_useCustomCode ? 'Creer avec mon code' : 'Creer ma famille', style: const TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildJoinSection(Color primary) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        NeonText(text: 'Rejoindre une famille', fontSize: 13, fontWeight: FontWeight.w700, color: Colors.orange, glowIntensity: 0.3),
        const SizedBox(height: 8),
        GlassCard(
          margin: EdgeInsets.zero,
          padding: const EdgeInsets.all(20),
          borderRadius: 20,
          glowColor: Colors.orange,
          child: Column(
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.orange.withValues(alpha: 0.12),
                  boxShadow: [BoxShadow(color: Colors.orange.withValues(alpha: 0.15), blurRadius: 12)],
                ),
                child: const Icon(Icons.people_rounded, color: Colors.orange, size: 32),
              ),
              const SizedBox(height: 16),
              const Text('Entrez le code pour rejoindre.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              TextField(
                controller: _joinController,
                textCapitalization: TextCapitalization.characters,
                textAlign: TextAlign.center,
                maxLength: 10,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 4, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'CODE',
                  counterText: '',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.paste_rounded),
                    onPressed: () async {
                      final data = await Clipboard.getData(Clipboard.kTextPlain);
                      if (data?.text != null) _joinController.text = data!.text!.toUpperCase().trim();
                    },
                  ),
                ),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]'))],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _joinFamily,
                  icon: const Icon(Icons.login_rounded),
                  label: const Text('Rejoindre', style: TextStyle(fontSize: 16)),
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.orange,
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

  Widget _buildInfoCard(Color primary) {
    return GlassCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(16),
      borderRadius: 18,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GlowIcon(icon: Icons.info_outline_rounded, size: 18, color: primary),
              const SizedBox(width: 8),
              NeonText(text: 'Comment ca marche ?', fontSize: 14, fontWeight: FontWeight.w700, color: primary, glowIntensity: 0.3),
            ],
          ),
          const SizedBox(height: 12),
          ...[
            (Icons.looks_one_rounded, 'Un parent cree la famille'),
            (Icons.looks_two_rounded, 'Il copie et partage le code'),
            (Icons.looks_3_rounded, 'L\'autre parent colle le code'),
            (Icons.looks_4_rounded, 'Les donnees se synchronisent !'),
          ].map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(item.$1, size: 20, color: primary),
                const SizedBox(width: 10),
                Expanded(child: Text(item.$2, style: TextStyle(fontSize: 13, color: Colors.grey[400]))),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
