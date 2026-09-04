import 'package:flutter/material.dart';

import 'calendar_event.dart';

enum CalendarAudienceKind { all, member, multiple, unknown }

@immutable
class CalendarAudienceStyle {
  const CalendarAudienceStyle({
    required this.kind,
    required this.background,
    required this.foreground,
    this.indicatorColors = const [],
  });

  final CalendarAudienceKind kind;
  final Color background;
  final Color foreground;
  final List<Color> indicatorColors;
}

/// UI-only color mapping. No color is persisted with members or events.
final class MemberColorResolver {
  const MemberColorResolver._();

  static const all = CalendarAudienceStyle(
    kind: CalendarAudienceKind.all,
    background: Color(0xFFEAE4F2),
    foreground: Color(0xFF4F435F),
  );

  static const unknown = CalendarAudienceStyle(
    kind: CalendarAudienceKind.unknown,
    background: Color(0xFFE7E7EA),
    foreground: Color(0xFF4A4A50),
  );

  static const _multipleBackground = Color(0xFFE9E6F5);
  static const _multipleForeground = Color(0xFF453D68);

  static const _palette = <CalendarAudienceStyle>[
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFEFD6DE),
      foreground: Color(0xFF6A3343),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFD7E4F4),
      foreground: Color(0xFF274C77),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFD8EBDD),
      foreground: Color(0xFF2F5D42),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFF3DFC8),
      foreground: Color(0xFF704423),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFE4DAF2),
      foreground: Color(0xFF503B72),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFD4EAE8),
      foreground: Color(0xFF285D59),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFF3E8C7),
      foreground: Color(0xFF66531B),
    ),
    CalendarAudienceStyle(
      kind: CalendarAudienceKind.member,
      background: Color(0xFFDCE0F4),
      foreground: Color(0xFF394675),
    ),
  ];

  static CalendarAudienceStyle forMemberId(String memberId) =>
      _palette[_stableHash(memberId) % _palette.length];

  static CalendarAudienceStyle forEvent(
    CalendarEvent event,
    Map<String, String> memberLabels,
  ) {
    if (event.appliesToAllMembers) return all;
    final ids = event.assignedMemberIds.toList()..sort();
    if (ids.length == 1) {
      return memberLabels.containsKey(ids.single)
          ? forMemberId(ids.single)
          : unknown;
    }
    return CalendarAudienceStyle(
      kind: CalendarAudienceKind.multiple,
      background: _multipleBackground,
      foreground: _multipleForeground,
      indicatorColors: [
        for (final id in ids)
          memberLabels.containsKey(id)
              ? forMemberId(id).background
              : unknown.background,
      ],
    );
  }

  static int _stableHash(String value) {
    var hash = 0;
    for (final unit in value.codeUnits) {
      hash = (hash * 31 + unit) & 0x7fffffff;
    }
    return hash;
  }
}
