import 'package:flutter/material.dart';

import '../services/family_manager_service.dart';

class FamilyManagersScreen extends StatefulWidget {
  const FamilyManagersScreen({
    required this.familyId,
    super.key,
  });

  final String familyId;

  @override
  State<FamilyManagersScreen> createState() => _FamilyManagersScreenState();
}

class _FamilyManagersScreenState extends State<FamilyManagersScreen> {
  final _service = FamilyManagerService();
  List<FamilyManagerMember> _members = const [];
  bool _busy = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final members = await _service.listMembers(widget.familyId);
      if (!mounted) return;
      setState(() {
        _members = members;
        _busy = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _changeRole(FamilyManagerMember member) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (member.role == 'manager') {
        await _service.revokeManager(
          familyId: widget.familyId,
          memberId: member.memberId,
        );
      } else {
        await _service.setManager(
          familyId: widget.familyId,
          memberId: member.memberId,
        );
      }
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionnaires de famille')),
      body: SafeArea(
        child: _busy && _members.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Un gestionnaire peut traiter les rattachements, '
                          'la cloche et le code familial. Il ne peut ni '
                          'transférer la propriété ni nommer un gestionnaire.',
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _error!,
                        style: const TextStyle(color: Colors.redAccent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    if (_members.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('Aucun parent actif disponible.'),
                        ),
                      ),
                    ..._members.map(
                      (member) => Card(
                        child: ListTile(
                          leading: Icon(
                            member.role == 'manager'
                                ? Icons.admin_panel_settings_rounded
                                : Icons.person_rounded,
                          ),
                          title: Text(member.displayName),
                          subtitle: Text(
                            member.role == 'manager'
                                ? 'Gestionnaire actif'
                                : member.durable
                                    ? 'Parent — compte durable vérifié'
                                    : 'Parent — compte durable requis',
                          ),
                          trailing: FilledButton(
                            onPressed: _busy ||
                                    (!member.durable &&
                                        member.role != 'manager')
                                ? null
                                : () => _changeRole(member),
                            child: Text(
                              member.role == 'manager' ? 'Révoquer' : 'Nommer',
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_busy)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                  ],
                ),
              ),
      ),
    );
  }
}
