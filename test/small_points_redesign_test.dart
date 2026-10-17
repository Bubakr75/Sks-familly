import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:family_score/config/emerald_theme.dart';
import 'package:family_score/models/child_model.dart';
import 'package:family_score/models/punishment_lines.dart';
import 'package:family_score/providers/family_provider.dart';
import 'package:family_score/widgets/sanction_selector.dart';
import 'package:family_score/widgets/screen_time_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DemoPointsFamily extends FamilyProvider {
  DemoPointsFamily(int balance)
      : child = ChildModel(id: 'lina', name: 'Lina', points: balance);
  final ChildModel child;
  int purchaseCount = 0;
  bool blocked = false;
  @override
  bool isScreenAccessBlocked(String childId) => blocked;
  @override
  Future<void> purchaseScreenTime(String childId, int minutes) async {
    purchaseCount++;
    child.points -= minutes == 30 ? 3 : 5;
    notifyListeners();
  }
}

void main() {
  for (final category in [('Rédaction / réflexion', 'essay'), ('🟨 Carton jaune', 'yellow_card'), ('🟥 Carton rouge', 'red_card')]) {
    testWidgets('catégorie ${category.$2} distincte et consigne proposée', (tester) async {
      String? type; String instruction = '';
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: SanctionSelector(enabled: true, onChanged: (t,l,i) { type=t; instruction=i; }))));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>)); await tester.pumpAndSettle();
      await tester.tap(find.text(category.$1).last); await tester.pumpAndSettle();
      expect(type, category.$2); expect(instruction, isNotEmpty);
      if (type != 'essay') expect(find.textContaining('Aucune durée imposée'), findsOneWidget);
    });
  }
  test('rédaction et cartons restent bloqués après synchronisation', () {
    for (final type in ['essay','yellow_card','red_card','repair']) {
      final p = PunishmentLines(id:'s',childId:'c',text:'Consigne',totalLines:type=='essay'?10:1,penaltyHistoryId:'a',sanctionType:type);
      final restored = PunishmentLines.fromMap(p.toMap());
      expect(restored.blocksScreenAccess,isTrue); expect(restored.isWriting,type=='essay');
      restored.status=PenaltyLinesStatus.completed; expect(restored.blocksScreenAccess,isFalse);
    }
  });
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('la corvée reste bloquante après relecture jusqu’à validation parent',
      () {
    final chore = PunishmentLines(
        id: 'task',
        childId: 'lina',
        text: 'Ranger les jouets',
        totalLines: 1,
        penaltyHistoryId: 'action',
        sanctionType: 'chore',
        sanctionLabel: 'Corvée');
    final restored = PunishmentLines.fromMap(chore.toMap());
    expect(restored.isLines, isFalse);
    expect(restored.blocksScreenAccess, isTrue);
    restored.status = PenaltyLinesStatus.completed;
    expect(restored.blocksScreenAccess, isFalse);
  });

  for (final points in [2, 3, 5]) {
    testWidgets('achat accessible au solde exact de $points points',
        (tester) async {
      final fp = DemoPointsFamily(points);
      await tester.pumpWidget(ChangeNotifierProvider<FamilyProvider>.value(
          value: fp,
          child: MaterialApp(
              home: Scaffold(body: ScreenTimeStore(child: fp.child)))));
      final halfHour = tester
          .widget<FilledButton>(find.byKey(const ValueKey('screen_buy_30')));
      final hour = tester
          .widget<FilledButton>(find.byKey(const ValueKey('screen_buy_60')));
      expect(halfHour.onPressed != null, points >= 3);
      expect(hour.onPressed != null, points >= 5);
      if (points >= 3) {
        await tester.tap(find
            .byKey(ValueKey(points == 5 ? 'screen_buy_60' : 'screen_buy_30')));
        await tester.pumpAndSettle();
        expect(fp.child.points, 0);
        expect(fp.purchaseCount, 1);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('sanction en attente désactive les achats', (tester) async {
    final fp = DemoPointsFamily(5)..blocked = true;
    await tester.pumpWidget(ChangeNotifierProvider<FamilyProvider>.value(
        value: fp,
        child: MaterialApp(
            home: Scaffold(body: ScreenTimeStore(child: fp.child)))));
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('screen_buy_30')))
            .onPressed,
        isNull);
    expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('screen_buy_60')))
            .onPressed,
        isNull);
  });

  testWidgets('la liste distingue lignes et corvées', (tester) async {
    String? selectedType;
    String? selectedInstruction;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SanctionSelector(
                enabled: true,
                onChanged: (type, label, instruction) {
                  selectedType = type;
                  selectedInstruction = instruction;
                }))));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Corvée').last);
    await tester.pumpAndSettle();
    expect(find.text('Action à effectuer'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField<String>).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ranger sa chambre').last);
    await tester.pumpAndSettle();
    expect(selectedType, 'chore');
    expect(selectedInstruction, 'Ranger sa chambre');
  });

  testWidgets('aperçus des nouveaux écrans à 390 pixels', (tester) async {
    await tester.runAsync(() async {
      final textFont = FontLoader('Preview');
      textFont.addFont(
          File('${Platform.environment['WINDIR']}/Fonts/segoeui.ttf')
              .readAsBytes()
              .then((data) => ByteData.sublistView(data)));
      await textFont.load();
      final iconFont = FontLoader('MaterialIcons');
      final packages = jsonDecode(
          await File('.dart_tool/package_config.json').readAsString()) as Map;
      final flutter = (packages['packages'] as List)
          .cast<Map>()
          .firstWhere((package) => package['name'] == 'flutter');
      final sdk = Directory.fromUri(Uri.parse(flutter['rootUri'] as String))
          .parent
          .parent
          .path;
      iconFont.addFont(File(
              '$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf')
          .readAsBytes()
          .then((data) => ByteData.sublistView(data)));
      await iconFont.load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final key = GlobalKey();
    final fp = DemoPointsFamily(5);
    Widget frame(Widget body, String title) => RepaintBoundary(
        key: key,
        child: ChangeNotifierProvider<FamilyProvider>.value(
            value: fp,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeData(
                    fontFamily: 'Preview',
                    brightness: Brightness.dark,
                    colorSchemeSeed: EmeraldPalette.emerald,
                    scaffoldBackgroundColor: EmeraldPalette.background),
                home: Scaffold(
                    appBar: AppBar(title: Text(title)),
                    body: Padding(
                        padding: const EdgeInsets.all(20), child: body)))));
    Future<void> save(String filename) async {
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory('../../outputs').create(recursive: true);
      await File('../../outputs/$filename')
          .writeAsBytes(bytes!.buffer.asUint8List());
    }

    await tester.pumpWidget(frame(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Bonjour Lina',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          ScreenTimeStore(child: fp.child)
        ]),
        'Mon temps d’écran'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => save('apercu-temps-ecran.png'));
    await tester.pumpWidget(frame(
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Une règle claire, un suivi simple.',
              style: TextStyle(fontSize: 22)),
          const SizedBox(height: 24),
          SanctionSelector(enabled: true, onChanged: (_, label, instruction) {})
        ]),
        'Choisir une sanction'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() => save('apercu-sanctions.png'));
  },
      skip: !Platform.isWindows ||
          Platform.environment['SKS_EXPORT_PREVIEWS'] != '1');
}
