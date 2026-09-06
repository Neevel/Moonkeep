import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/account/account_screen.dart';
import 'package:moonkeep/features/calendar/calendar_screen.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';
import 'package:moonkeep/features/calendar/member_color_resolver.dart';
import 'package:moonkeep/features/family/family_screen.dart';
import 'package:moonkeep/theme/moonkeep_theme.dart';
import 'package:moonkeep/theme/moonkeep_theme_controller.dart';

class FakeThemeStore implements MoonkeepThemeStore {
  FakeThemeStore([this.value]);

  String? value;
  final writes = <String>[];

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async {
    this.value = value;
    writes.add(value);
  }
}

void main() {
  test(
    'theme loading defaults safely and restores valid persisted values',
    () async {
      final defaultController = await MoonkeepThemeController.load(
        store: FakeThemeStore(),
      );
      expect(defaultController.themeId, MoonkeepThemeId.moonkeep);

      final restored = await MoonkeepThemeController.load(
        store: FakeThemeStore(MoonkeepThemeId.ancientGrimoire.name),
      );
      expect(restored.themeId, MoonkeepThemeId.ancientGrimoire);

      final invalid = await MoonkeepThemeController.load(
        store: FakeThemeStore('old-or-invalid-theme'),
      );
      expect(invalid.themeId, MoonkeepThemeId.moonkeep);
    },
  );

  test('selecting a theme persists its stable id', () async {
    final store = FakeThemeStore();
    final controller = MoonkeepThemeController(store: store);
    await controller.select(MoonkeepThemeId.enchantedForest);
    expect(controller.themeId, MoonkeepThemeId.enchantedForest);
    expect(store.writes, [MoonkeepThemeId.enchantedForest.name]);
  });

  test('all five theme ids provide complete central theme data', () {
    for (final id in MoonkeepThemeId.values) {
      final theme = MoonkeepThemes.themeFor(id);
      final colors = theme.extension<MoonkeepThemeColors>();
      expect(theme.useMaterial3, isTrue, reason: id.name);
      expect(colors, isNotNull, reason: id.name);
      expect(colors!.memberBackgrounds, hasLength(8), reason: id.name);
      expect(colors.memberForegrounds, hasLength(8), reason: id.name);
      for (var index = 0; index < 8; index++) {
        final style = MemberColorResolver.forMemberId(
          'member-$index',
          theme: colors,
        );
        final again = MemberColorResolver.forMemberId(
          'member-$index',
          theme: colors,
        );
        expect(style.background, again.background, reason: id.name);
        expect(
          _contrast(style.background, style.foreground),
          greaterThanOrEqualTo(4.5),
          reason: '${id.name} member $index',
        );
      }
    }
  });

  testWidgets('calendar renders while switching live through all five themes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = MoonkeepThemeController();
    addTearDown(controller.dispose);
    final store = CalendarStore(read: () async => null, write: (_) async {});
    await tester.pumpWidget(
      MoonkeepApp(store: store, themeController: controller),
    );
    await tester.pumpAndSettle();

    for (final id in MoonkeepThemeId.values) {
      await controller.select(id);
      await tester.pumpAndSettle();
      expect(find.byType(CalendarScreen), findsOneWidget, reason: id.name);
      final context = tester.element(find.byType(CalendarScreen));
      expect(
        Theme.of(context).extension<MoonkeepThemeColors>(),
        isNotNull,
        reason: id.name,
      );
      expect(tester.takeException(), isNull, reason: id.name);
    }
  });

  testWidgets('account and family surfaces render in dark and fantasy themes', (
    tester,
  ) async {
    for (final id in MoonkeepThemeId.values.skip(1)) {
      await tester.pumpWidget(
        MaterialApp(
          theme: MoonkeepThemes.themeFor(id),
          home: const AccountScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mein Konto'), findsOneWidget, reason: id.name);
      expect(tester.takeException(), isNull, reason: id.name);

      await tester.pumpWidget(
        MaterialApp(
          theme: MoonkeepThemes.themeFor(id),
          home: const FamilyScreen(auth: null, repository: null),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Kalender einrichten'), findsOneWidget, reason: id.name);
      expect(tester.takeException(), isNull, reason: id.name);
    }
  });
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + 0.05) / (darker + 0.05);
}
