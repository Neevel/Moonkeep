import 'package:flutter/material.dart';

enum MoonkeepThemeId {
  moonkeep,
  obsidian,
  ancientGrimoire,
  dungeonKeep,
  enchantedForest,
}

extension MoonkeepThemeIdText on MoonkeepThemeId {
  String get label => switch (this) {
    MoonkeepThemeId.moonkeep => 'Moonkeep',
    MoonkeepThemeId.obsidian => 'Obsidian',
    MoonkeepThemeId.ancientGrimoire => 'Ancient Grimoire',
    MoonkeepThemeId.dungeonKeep => 'Dungeon Keep',
    MoonkeepThemeId.enchantedForest => 'Enchanted Forest',
  };

  String get description => switch (this) {
    MoonkeepThemeId.moonkeep => 'Hell, weich und freundlich',
    MoonkeepThemeId.obsidian => 'Modernes Dark Theme',
    MoonkeepThemeId.ancientGrimoire => 'Warmes Pergament und gedämpftes Gold',
    MoonkeepThemeId.dungeonKeep => 'Dunkler Stein, Bronze und alte Festungen',
    MoonkeepThemeId.enchantedForest => 'Waldgrün, Salbei und sanfte Magie',
  };
}

@immutable
class MoonkeepThemeColors extends ThemeExtension<MoonkeepThemeColors> {
  const MoonkeepThemeColors({
    required this.calendarCell,
    required this.calendarCellOutsideMonth,
    required this.calendarToday,
    required this.calendarSelected,
    required this.settingsCard,
    required this.allMembersBackground,
    required this.allMembersForeground,
    required this.unknownMemberBackground,
    required this.unknownMemberForeground,
    required this.multipleMembersBackground,
    required this.multipleMembersForeground,
    required this.memberBackgrounds,
    required this.memberForegrounds,
  });

  final Color calendarCell;
  final Color calendarCellOutsideMonth;
  final Color calendarToday;
  final Color calendarSelected;
  final Color settingsCard;
  final Color allMembersBackground;
  final Color allMembersForeground;
  final Color unknownMemberBackground;
  final Color unknownMemberForeground;
  final Color multipleMembersBackground;
  final Color multipleMembersForeground;
  final List<Color> memberBackgrounds;
  final List<Color> memberForegrounds;

  @override
  MoonkeepThemeColors copyWith({
    Color? calendarCell,
    Color? calendarCellOutsideMonth,
    Color? calendarToday,
    Color? calendarSelected,
    Color? settingsCard,
    Color? allMembersBackground,
    Color? allMembersForeground,
    Color? unknownMemberBackground,
    Color? unknownMemberForeground,
    Color? multipleMembersBackground,
    Color? multipleMembersForeground,
    List<Color>? memberBackgrounds,
    List<Color>? memberForegrounds,
  }) => MoonkeepThemeColors(
    calendarCell: calendarCell ?? this.calendarCell,
    calendarCellOutsideMonth:
        calendarCellOutsideMonth ?? this.calendarCellOutsideMonth,
    calendarToday: calendarToday ?? this.calendarToday,
    calendarSelected: calendarSelected ?? this.calendarSelected,
    settingsCard: settingsCard ?? this.settingsCard,
    allMembersBackground: allMembersBackground ?? this.allMembersBackground,
    allMembersForeground: allMembersForeground ?? this.allMembersForeground,
    unknownMemberBackground:
        unknownMemberBackground ?? this.unknownMemberBackground,
    unknownMemberForeground:
        unknownMemberForeground ?? this.unknownMemberForeground,
    multipleMembersBackground:
        multipleMembersBackground ?? this.multipleMembersBackground,
    multipleMembersForeground:
        multipleMembersForeground ?? this.multipleMembersForeground,
    memberBackgrounds: memberBackgrounds ?? this.memberBackgrounds,
    memberForegrounds: memberForegrounds ?? this.memberForegrounds,
  );

  @override
  MoonkeepThemeColors lerp(covariant MoonkeepThemeColors? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

final class MoonkeepThemes {
  const MoonkeepThemes._();

  static ThemeData themeFor(MoonkeepThemeId id) => switch (id) {
    MoonkeepThemeId.moonkeep => _build(
      brightness: Brightness.light,
      seed: const Color(0xFF65558F),
      background: const Color(0xFFF9F7FC),
      surface: const Color(0xFFFFFBFF),
      radius: 16,
      colors: _moonkeep,
    ),
    MoonkeepThemeId.obsidian => _build(
      brightness: Brightness.dark,
      seed: const Color(0xFFB69CFF),
      background: const Color(0xFF17151C),
      surface: const Color(0xFF211E29),
      radius: 14,
      colors: _obsidian,
    ),
    MoonkeepThemeId.ancientGrimoire => _build(
      brightness: Brightness.light,
      seed: const Color(0xFF7B5A24),
      background: const Color(0xFFF2E5C5),
      surface: const Color(0xFFFFF4D8),
      radius: 8,
      colors: _grimoire,
    ),
    MoonkeepThemeId.dungeonKeep => _build(
      brightness: Brightness.dark,
      seed: const Color(0xFFBE8A45),
      background: const Color(0xFF191816),
      surface: const Color(0xFF27241F),
      radius: 7,
      colors: _dungeon,
    ),
    MoonkeepThemeId.enchantedForest => _build(
      brightness: Brightness.light,
      seed: const Color(0xFF37694E),
      background: const Color(0xFFE8F0E3),
      surface: const Color(0xFFF7F4E8),
      radius: 18,
      colors: _forest,
    ),
  };

  static ThemeData _build({
    required Brightness brightness,
    required Color seed,
    required Color background,
    required Color surface,
    required double radius,
    required MoonkeepThemeColors colors,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(surface: surface);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.45)),
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: background,
      cardTheme: CardThemeData(
        color: colors.settingsCard,
        elevation: brightness == Brightness.dark ? 1 : 0.8,
        shape: shape,
      ),
      dialogTheme: DialogThemeData(backgroundColor: surface, shape: shape),
      inputDecorationTheme: InputDecorationTheme(
        filled: brightness == Brightness.dark,
        fillColor: scheme.surfaceContainerHigh,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius * 0.75),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      ),
      chipTheme: ChipThemeData(
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
      ),
      extensions: [colors],
    );
  }

  static const _moonkeep = MoonkeepThemeColors(
    calendarCell: Color(0xFFFFFBFF),
    calendarCellOutsideMonth: Color(0xFFF4F0F7),
    calendarToday: Color(0xFF65558F),
    calendarSelected: Color(0xFFE9DDFF),
    settingsCard: Color(0xFFFFF7FF),
    allMembersBackground: Color(0xFFEAE4F2),
    allMembersForeground: Color(0xFF4F435F),
    unknownMemberBackground: Color(0xFFE7E7EA),
    unknownMemberForeground: Color(0xFF4A4A50),
    multipleMembersBackground: Color(0xFFE9E6F5),
    multipleMembersForeground: Color(0xFF453D68),
    memberBackgrounds: [
      Color(0xFFEFD6DE),
      Color(0xFFD7E4F4),
      Color(0xFFD8EBDD),
      Color(0xFFF3DFC8),
      Color(0xFFE4DAF2),
      Color(0xFFD4EAE8),
      Color(0xFFF3E8C7),
      Color(0xFFDCE0F4),
    ],
    memberForegrounds: [
      Color(0xFF6A3343),
      Color(0xFF274C77),
      Color(0xFF2F5D42),
      Color(0xFF704423),
      Color(0xFF503B72),
      Color(0xFF285D59),
      Color(0xFF66531B),
      Color(0xFF394675),
    ],
  );

  static const _obsidian = MoonkeepThemeColors(
    calendarCell: Color(0xFF211E29),
    calendarCellOutsideMonth: Color(0xFF19171F),
    calendarToday: Color(0xFFC8B5FF),
    calendarSelected: Color(0xFF443568),
    settingsCard: Color(0xFF25212E),
    allMembersBackground: Color(0xFF3D354C),
    allMembersForeground: Color(0xFFF0E8FF),
    unknownMemberBackground: Color(0xFF3B3A40),
    unknownMemberForeground: Color(0xFFE7E3EA),
    multipleMembersBackground: Color(0xFF403A5A),
    multipleMembersForeground: Color(0xFFF1ECFF),
    memberBackgrounds: [
      Color(0xFF5B3040),
      Color(0xFF294867),
      Color(0xFF28533B),
      Color(0xFF654522),
      Color(0xFF49366A),
      Color(0xFF245653),
      Color(0xFF5B4D20),
      Color(0xFF36436A),
    ],
    memberForegrounds: [
      Color(0xFFFFD9E3),
      Color(0xFFD5E8FF),
      Color(0xFFD5F2DE),
      Color(0xFFFFE0BD),
      Color(0xFFE9DBFF),
      Color(0xFFCEF2EF),
      Color(0xFFFFE9A9),
      Color(0xFFDDE3FF),
    ],
  );

  static const _grimoire = MoonkeepThemeColors(
    calendarCell: Color(0xFFFFF1CF),
    calendarCellOutsideMonth: Color(0xFFE8D8B5),
    calendarToday: Color(0xFF8A5E13),
    calendarSelected: Color(0xFFE1C27B),
    settingsCard: Color(0xFFF9EBCB),
    allMembersBackground: Color(0xFFE4D2A9),
    allMembersForeground: Color(0xFF4D381A),
    unknownMemberBackground: Color(0xFFD8CEB9),
    unknownMemberForeground: Color(0xFF443E33),
    multipleMembersBackground: Color(0xFFDDC995),
    multipleMembersForeground: Color(0xFF493716),
    memberBackgrounds: [
      Color(0xFFE7C0AC),
      Color(0xFFBFD0D0),
      Color(0xFFC4D1AC),
      Color(0xFFE2C28E),
      Color(0xFFCAB9D0),
      Color(0xFFB8D2C4),
      Color(0xFFE0D19A),
      Color(0xFFBCC3D2),
    ],
    memberForegrounds: [
      Color(0xFF5A2D20),
      Color(0xFF27484A),
      Color(0xFF354820),
      Color(0xFF593B12),
      Color(0xFF473153),
      Color(0xFF254A3B),
      Color(0xFF51430E),
      Color(0xFF303A55),
    ],
  );

  static const _dungeon = MoonkeepThemeColors(
    calendarCell: Color(0xFF282520),
    calendarCellOutsideMonth: Color(0xFF1D1B18),
    calendarToday: Color(0xFFD5A25D),
    calendarSelected: Color(0xFF594125),
    settingsCard: Color(0xFF2C2924),
    allMembersBackground: Color(0xFF484038),
    allMembersForeground: Color(0xFFFFE8C8),
    unknownMemberBackground: Color(0xFF3D3B38),
    unknownMemberForeground: Color(0xFFE7E0D7),
    multipleMembersBackground: Color(0xFF514536),
    multipleMembersForeground: Color(0xFFFFE5BD),
    memberBackgrounds: [
      Color(0xFF633640),
      Color(0xFF334B5E),
      Color(0xFF34513C),
      Color(0xFF664520),
      Color(0xFF4F3B60),
      Color(0xFF31504D),
      Color(0xFF5B4E27),
      Color(0xFF3D465E),
    ],
    memberForegrounds: [
      Color(0xFFFFD9DF),
      Color(0xFFDCEBFA),
      Color(0xFFDDF0DF),
      Color(0xFFFFE1B8),
      Color(0xFFEADFFF),
      Color(0xFFD5EEEA),
      Color(0xFFFFE9B3),
      Color(0xFFE0E5F5),
    ],
  );

  static const _forest = MoonkeepThemeColors(
    calendarCell: Color(0xFFF5F3E7),
    calendarCellOutsideMonth: Color(0xFFDDE6D7),
    calendarToday: Color(0xFF2F6848),
    calendarSelected: Color(0xFFBFD8BE),
    settingsCard: Color(0xFFF2F2E5),
    allMembersBackground: Color(0xFFD8E3D2),
    allMembersForeground: Color(0xFF2D4935),
    unknownMemberBackground: Color(0xFFE0E1D8),
    unknownMemberForeground: Color(0xFF44483F),
    multipleMembersBackground: Color(0xFFCEDDC6),
    multipleMembersForeground: Color(0xFF294331),
    memberBackgrounds: [
      Color(0xFFE8CDD0),
      Color(0xFFC9DCE4),
      Color(0xFFC8E0CD),
      Color(0xFFE8D4B6),
      Color(0xFFD8CDE5),
      Color(0xFFC4DEDA),
      Color(0xFFE6DDBA),
      Color(0xFFCFD5E5),
    ],
    memberForegrounds: [
      Color(0xFF62323A),
      Color(0xFF2B4B5A),
      Color(0xFF31563A),
      Color(0xFF65451D),
      Color(0xFF4D3B63),
      Color(0xFF28534E),
      Color(0xFF584D1C),
      Color(0xFF394663),
    ],
  );
}
