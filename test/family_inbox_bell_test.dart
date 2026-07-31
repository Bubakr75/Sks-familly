import 'package:family_score/widgets/family_inbox_bell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final size in const [
    Size(320, 568),
    Size(375, 812),
    Size(390, 844),
  ]) {
    testWidgets('cloche visible sans overflow sur ${size.width.toInt()} px',
        (tester) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topRight,
            child: FamilyInboxBell(
              unreadCount: 12,
              onTap: () => tapped = true,
            ),
          ),
        ),
      ));

      expect(find.byKey(const ValueKey('family-inbox-bell')), findsOneWidget);
      expect(find.text('9+'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('family-inbox-bell')));
      expect(tapped, isTrue);
    });
  }
}
