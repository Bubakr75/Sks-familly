import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';

class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final _auth = AuthService();

  late FirebaseAccountStatus _status;
  bool _busy = false;
  bool _signInMode = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    _status = _auth.accountStatus;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!_signInMode &&
        _passwordController.text != _confirmationController.text) {
      _setMessage('Les deux mots de passe sont différents.', error: true);
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      if (_signInMode) {
        await _auth.signInWithEmailPassword(
          email: _emailController.text,
          password: _passwordController.text,
        );
        final familyId = FirestoreService().familyId;
        if (familyId != null) {
          try {
            await FirestoreService().verifyApprovedFamilyAccess(familyId);
            FirestoreService().reconnect();
          } catch (_) {
            _setMessage(
              'Compte connecté, mais ce compte n’a pas accès à la famille '
              'locale. Reprenez le rattachement depuis Synchronisation.',
              error: true,
            );
          }
        }
      } else {
        await _auth.secureTemporaryAccount(
          email: _emailController.text,
          password: _passwordController.text,
        );
      }
      _clearPasswords();
      final status = await _auth.refreshAccountStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
        _message ??= _signInMode
            ? 'Compte durable reconnecté.'
            : 'Compte sécurisé. Vérifiez maintenant votre adresse email.';
      });
    } catch (error) {
      _clearPasswords();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = true;
        _message = error.toString();
      });
    }
  }

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      final status = await _auth.refreshAccountStatus();
      if (!mounted) return;
      setState(() {
        _status = status;
        _busy = false;
        _messageIsError = false;
        _message = status.emailVerified
            ? 'Adresse email vérifiée.'
            : 'La vérification email est encore en attente.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = true;
        _message = error.toString();
      });
    }
  }

  Future<void> _resendVerification() async {
    setState(() => _busy = true);
    try {
      await _auth.sendVerificationEmail();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = false;
        _message = 'Email de vérification renvoyé.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _messageIsError = true;
        _message = error.toString();
      });
    }
  }

  void _setMessage(String message, {required bool error}) {
    setState(() {
      _message = message;
      _messageIsError = error;
    });
  }

  void _clearPasswords() {
    _passwordController.clear();
    _confirmationController.clear();
  }

  @override
  Widget build(BuildContext context) {
    final durable = _status.isDurable;
    return Scaffold(
      appBar: AppBar(title: const Text('Sécurité du compte')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  children: [
                    Icon(
                      durable
                          ? Icons.verified_user_rounded
                          : Icons.person_outline_rounded,
                      size: 48,
                      color: durable ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      durable ? 'Compte sécurisé' : 'Compte temporaire',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text('Méthode : ${_status.provider}'),
                    if (_status.maskedEmail != null)
                      Text('Adresse : ${_status.maskedEmail}'),
                    Text(
                      durable
                          ? _status.emailVerified
                              ? 'Adresse email vérifiée'
                              : 'Adresse email non vérifiée'
                          : 'Cet UID dépend encore de la session Firebase.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (!durable) ...[
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: false,
                    label: Text('Sécuriser ce compte'),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text('Compte existant'),
                  ),
                ],
                selected: {_signInMode},
                onSelectionChanged: _busy
                    ? null
                    : (selection) {
                        setState(() {
                          _signInMode = selection.first;
                          _message = null;
                          _clearPasswords();
                        });
                      },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                enabled: !_busy,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Adresse email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                enabled: !_busy,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: const [AutofillHints.password],
                decoration: const InputDecoration(
                  labelText: 'Mot de passe',
                  helperText: '10 caractères minimum',
                  prefixIcon: Icon(Icons.lock_outline_rounded),
                ),
              ),
              if (!_signInMode) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _confirmationController,
                  enabled: !_busy,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Confirmer le mot de passe',
                    prefixIcon: Icon(Icons.lock_reset_rounded),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _busy ? null : _submit,
                icon: const Icon(Icons.security_rounded),
                label: Text(
                  _signInMode
                      ? 'Se reconnecter'
                      : 'Sécuriser sans changer d’UID',
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Si l’adresse appartient déjà à un autre compte, aucune '
                'fusion automatique ne sera faite.',
                textAlign: TextAlign.center,
              ),
            ] else if (!_status.emailVerified) ...[
              FilledButton.icon(
                onPressed: _busy ? null : _resendVerification,
                icon: const Icon(Icons.mark_email_unread_rounded),
                label: const Text('Renvoyer l’email de vérification'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('J’ai vérifié mon adresse'),
              ),
            ] else
              OutlinedButton.icon(
                onPressed: _busy ? null : _refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Actualiser le compte'),
              ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _messageIsError ? Colors.redAccent : Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}
