import 'package:family_score/widgets/point_action_feedback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'réussite visible sur le bon ScaffoldMessenger puis panneau fermé',
    (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            appBar: AppBar(title: const Text('Accueil')),
            body: Center(
              child: FilledButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const _SuccessRoute(),
                  ),
                ),
                child: const Text('Ouvrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Valider'));
      await tester.pump();
      expect(find.text('Bonus enregistré'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 150));
      expect(find.text('Accueil'), findsOneWidget);
      // Pendant la transition de route, Flutter peut peindre brièvement
      // l'ancien et le nouveau Scaffold avec le même SnackBar.
      expect(find.text('Bonus enregistré'), findsWidgets);
    },
  );

  testWidgets('échec visible et panneau conservé', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: _FailureRoute()));
    await tester.tap(find.text('Valider'));
    await tester.pump();
    expect(find.text('Serveur indisponible'), findsOneWidget);
    expect(find.text('Panneau'), findsOneWidget);
  });
}

class _SuccessRoute extends StatelessWidget {
  const _SuccessRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panneau')),
      body: FilledButton(
        onPressed: () async {
          final messenger = ScaffoldMessenger.of(context);
          showPointActionSuccess(
            messenger: messenger,
            message: 'Bonus enregistré',
            color: Colors.green,
          );
          await closePointActionPanelAfterSuccess(
            context,
            delay: const Duration(milliseconds: 100),
          );
        },
        child: const Text('Valider'),
      ),
    );
  }
}

class _FailureRoute extends StatelessWidget {
  const _FailureRoute();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Panneau')),
      body: FilledButton(
        onPressed: () {
          showPointActionFailure(
            messenger: ScaffoldMessenger.of(context),
            message: 'Serveur indisponible',
          );
        },
        child: const Text('Valider'),
      ),
    );
  }
}
