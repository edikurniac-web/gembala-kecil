import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gembala_kecil/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('home logo uses a cropped, top-left layout on phone width',
      (tester) async {
    tester.view.physicalSize = const Size(368, 698);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({'child_name': 'Dante'});
    final prefs = await SharedPreferences.getInstance();
    await tester
        .pumpWidget(MaterialApp(home: HomeScreen(name: 'Dante', prefs: prefs)));
    final logo = find.byWidgetPredicate((widget) =>
        widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName == 'assets/brand/logo.png');
    expect(logo, findsOneWidget);
    final image = tester.widget<Image>(logo);
    expect(image.width, 140);
    expect(image.fit, BoxFit.cover);
    expect(tester.getTopLeft(logo).dx, lessThan(20));
    expect(tester.takeException(), isNull);
  });

  testWidgets('existing local name still sees the new two-step onboarding once',
      (tester) async {
    SharedPreferences.setMockInitialValues({'child_name': 'Dante'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(GembalaApp(prefs: prefs));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Siapa nama panggilanmu?'), findsOneWidget);
    expect(find.byKey(const Key('child-name-input')), findsOneWidget);
    expect(find.text('Dante'), findsOneWidget);
    await tester.ensureVisible(find.text('Lanjutkan'));
    await tester.tap(find.text('Lanjutkan'));
    await tester.pumpAndSettle();
    expect(find.text('Buat Akun Orang Tua'), findsOneWidget);
    await tester.tap(find.text('Lewati Sekarang'));
    await tester.pumpAndSettle();
    expect(prefs.getBool('onboarding_complete'), isTrue);
    expect(find.textContaining('Halo, Dante!'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(GembalaApp(prefs: prefs));
    await tester.pump(const Duration(milliseconds: 1100));
    await tester.pumpAndSettle();
    expect(find.text('Siapa nama panggilanmu?'), findsNothing);
    expect(find.textContaining('Halo, Dante!'), findsOneWidget);
  });
}
