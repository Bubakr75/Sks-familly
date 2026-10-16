import 'package:family_score/models/child_model.dart';
import 'package:family_score/models/chore_model.dart';
import 'package:family_score/providers/family_provider.dart';
import 'package:family_score/providers/pin_provider.dart';
import 'package:family_score/screens/dashboard_screen.dart';
import 'package:family_score/screens/home_screen.dart';
import 'package:family_score/widgets/home_actions_panel.dart';
import 'package:family_score/widgets/home_bottom_navigation.dart';
import 'package:family_score/widgets/family_profiles_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

class DemoFamily extends FamilyProvider {
  DemoFamily({this.role, this.childId});
  final String? role;
  final String? childId;
  @override
  String? get memberRole => role;
  @override
  String? get memberChildId => childId;
  @override
  List<ChildModel> get children => [
        ChildModel(id: 'lina', name: 'Lina', points: 40),
        ChildModel(id: 'adam', name: 'Adam', points: 70),
      ];
  @override
  List<ChoreModel> get chores =>
      [ChoreModel(id: 'lit', label: 'Faire mon lit', points: 5)];
  @override
  List<Map<String, dynamic>> get pendingJoinRequests => [
        {'id': 'test'}
      ];
  @override
  int get pendingRequestsCount => pendingJoinRequests.length;
}

Widget wrap(Widget child, {bool parent = false, DemoFamily? family}) {
  final pin = PinProvider();
  if (parent) pin.unlockParentMode();
  return MultiProvider(
      providers: [
        ChangeNotifierProvider<FamilyProvider>(
            create: (_) => family ?? DemoFamily()),
        ChangeNotifierProvider(create: (_) => pin),
      ],
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: ThemeData(brightness: Brightness.dark, fontFamily: 'Arial'),
          home: child));
}

void main() {
  testWidgets('l’accueil reste lisible à 320 pixels', (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(wrap(const HomeScreen(), parent: true));
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.text('Réglages'), findsOneWidget);
  });

  testWidgets(
      'l’accueil enfant masque les décisions parentales et les autres profils',
      (tester) async {
    await tester.pumpWidget(wrap(const DashboardScreen(),
        family: DemoFamily(role: 'child', childId: 'lina')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.textContaining('à traiter'), findsNothing);
    expect(find.text('Adam'), findsNothing);
    expect(find.text('Lina'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('les profils sont alphabétiques sans modifier la liste source', () {
    final children = DemoFamily().children;
    final visible = visibleFamilyChildren(children,
        memberRole: 'parent', memberChildId: null);
    expect(visible.map((c) => c.id), ['adam', 'lina']);
    expect(children.first.id, 'lina');
  });

  test('un compte enfant ne voit que son profil et jamais un profil par défaut',
      () {
    expect(
        visibleFamilyChildren(DemoFamily().children,
                memberRole: 'child', memberChildId: 'lina')
            .map((c) => c.id),
        ['lina']);
    expect(
        visibleFamilyChildren(DemoFamily().children,
            memberRole: 'child', memberChildId: null),
        isEmpty);
  });

  testWidgets('bonus, pénalité et lignes ont un accès direct', (tester) async {
    int? selected;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: HomeBottomNavigation(
                selectedIndex: 0, onSelectTab: (i) => selected = i))));
    await tester.tap(find.text('Bonus'));
    expect(selected, 1);
    await tester.tap(find.text('Pénalité'));
    expect(selected, 2);
    await tester.tap(find.text('Lignes'));
    expect(selected, 3);
    expect(find.text('Checklist'), findsNothing);
  });

  testWidgets('le panneau enfant privilégie ses lignes sans action parentale',
      (tester) async {
    var opened = false;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: HomeActionsPanel(
                showParentActions: false,
                onBonus: () {},
                onPenalty: () {},
                onPhoto: () {},
                onTransfer: () {},
                onLines: () => opened = true))));
    expect(find.text('Bonus'), findsNothing);
    expect(find.text('Pénalité'), findsNothing);
    await tester.tap(find.text('Mes lignes et immunités'));
    expect(opened, isTrue);
  });

  testWidgets('l’accueil parent place les demandes avant les profils',
      (tester) async {
    await tester.pumpWidget(wrap(const DashboardScreen(), parent: true));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('1 demande à traiter'), findsOneWidget);
    expect(find.text('Ma famille'), findsOneWidget);
    expect(tester.getTopLeft(find.text('1 demande à traiter')).dy,
        lessThan(tester.getTopLeft(find.text('Ma famille')).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'l’accueil met les bonus, pénalités et lignes avant les outils secondaires',
      (tester) async {
    await tester.pumpWidget(wrap(const HomeScreen(), parent: true));
    await tester.pump(const Duration(seconds: 2));
    expect(find.byType(HomeActionsPanel), findsOneWidget);
    expect(find.text('Lignes de punition et immunités'), findsOneWidget);
    expect(find.text('Checklist du jour'), findsNothing);
    expect(tester.getTopLeft(find.byType(HomeActionsPanel)).dy,
        lessThan(tester.getTopLeft(find.text('Ma famille')).dy));
    expect(tester.takeException(), isNull);
  });
}
