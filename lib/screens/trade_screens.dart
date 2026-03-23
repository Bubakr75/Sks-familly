import 'package:flutter/material.dart';

class TradeScreen extends StatelessWidget {
  final String childId;

  const TradeScreen({
    super.key,
    this.childId = '',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Échanges d’immunité'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.swap_horiz_rounded,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: 20),
              Text(
                'Marché d’échange',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Cet écran a été ajouté pour corriger le build et préparer la fonctionnalité d’échange entre enfants.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              if (childId.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.colorScheme.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    'Enfant sélectionné : $childId',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.orange.withValues(alpha: 0.30),
                  ),
                ),
                child: Column(
                  children: const [
                    Icon(Icons.construction_rounded, size: 34, color: Colors.orange),
                    SizedBox(height: 10),
                    Text(
                      'Fonction en préparation',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Le système complet d’échange d’immunités pourra être branché ensuite sans re-bloquer l’application.',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),
              ElevatedButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Retour'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
