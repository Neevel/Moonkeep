import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/account/auth_repository.dart';
import 'package:moonkeep/features/calendar/calendar_repository.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';
import 'package:moonkeep/features/family/family_repository.dart';

class FakeAuth implements AuthRepository {
  FakeAuth(this.user);
  AccountIdentity? user;
  final changes = StreamController<AccountIdentity?>.broadcast();
  @override
  AccountIdentity? get currentUser => user;
  @override
  Stream<AccountIdentity?> get userChanges => changes.stream;
  @override
  Future<void> signIn(String email, String password) async {}
  @override
  Future<void> register(String email, String password) async {}
  @override
  Future<void> sendPasswordReset(String email) async {}
  @override
  Future<void> sendVerificationEmail() async {}
  @override
  Future<void> reloadUser() async {}
  @override
  Future<void> signOut() async {}
}

class FakeFamily implements FamilyRepository {
  Family? family;
  List<FamilyMember> familyMembers = const [
    FamilyMember(id: 'owner', email: 'owner@example.test', isOwner: true),
    FamilyMember(id: 'member', email: 'member@example.test', isOwner: false),
  ];
  int created = 0, joined = 0, invited = 0, revoked = 0, left = 0;
  @override
  bool canInvite(Family value) => value.ownerId == 'owner';
  @override
  Future<Family?> loadFamily() async => family;
  @override
  Future<Family> createFamily(String name) async {
    created++;
    family = Family(id: 'family', name: name.trim(), ownerId: 'owner');
    return family!;
  }

  @override
  Future<Family> joinFamily(String code) async {
    joined++;
    family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    return family!;
  }

  @override
  Future<List<FamilyMember>> members(Family family) async => familyMembers;

  @override
  Future<FamilyInvitation> invite(Family value) async {
    invited++;
    return FamilyInvitation(code: 'a' * 32, expiresAt: DateTime(2026, 9, 4));
  }

  @override
  Future<List<FamilyInvitation>> invitations(Family family) async => [];
  @override
  Future<void> revokeInvitation(String code) async {
    revoked++;
  }

  @override
  Future<void> leaveFamily(Family value) async {
    left++;
    family = null;
  }

  @override
  CalendarRepository calendar(Family family) => FakeSharedCalendar();
}

class FakeSharedCalendar extends CalendarStore {
  FakeSharedCalendar() : super(read: () async => null, write: (_) async {});
  @override
  bool get isShared => true;
  @override
  String get label => 'Jeske';
}

void main() {
  Future<(FakeAuth, FakeFamily)> open(
    WidgetTester tester, {
    bool verified = true,
  }) async {
    tester.view.physicalSize = const Size(500, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final auth = FakeAuth(
      AccountIdentity(email: 'test@example.test', emailVerified: verified),
    );
    final family = FakeFamily();
    addTearDown(auth.changes.close);
    await tester.pumpWidget(
      MoonkeepApp(auth: auth, family: family, autoOpenCalendar: false),
    );
    await tester.pumpAndSettle();
    return (auth, family);
  }

  testWidgets('requires verified email before exposing family actions', (
    tester,
  ) async {
    await open(tester, verified: false);
    expect(find.textContaining('bestätige zuerst'), findsOneWidget);
    expect(find.text('Kalender erstellen'), findsNothing);
  });

  testWidgets('creates family and generates revocable one-time invitation', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    for (final option in [
      'Familie',
      'Partnerschaft',
      'Freunde',
      'WG',
      'Sonstiges',
    ]) {
      expect(find.text(option), findsOneWidget);
    }
    await tester.tap(find.text('Sonstiges'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextField, 'Name des Kalenders'),
      '  Jeske  ',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kalender erstellen'));
    await tester.pumpAndSettle();
    expect(family.created, 1);
    expect(find.text('Jeske'), findsOneWidget);
    await tester.tap(find.text('Einladungscode erzeugen'));
    await tester.pumpAndSettle();
    expect(family.invited, 1);
    expect(find.text('a' * 32), findsOneWidget);
    await tester.tap(find.text('Widerrufen'));
    await tester.pumpAndSettle();
    expect(family.revoked, 1);
    expect(find.text('a' * 32), findsNothing);
  });

  testWidgets('existing membership opens the shared calendar on app start', (
    tester,
  ) async {
    final auth = FakeAuth(
      const AccountIdentity(email: 'test@example.test', emailVerified: true),
    );
    final family = FakeFamily()
      ..family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    addTearDown(auth.changes.close);
    await tester.pumpWidget(MoonkeepApp(auth: auth, family: family));
    await tester.pumpAndSettle();
    expect(find.text('Jeske'), findsOneWidget);
    expect(find.text('Termin anlegen'), findsOneWidget);
    expect(find.byTooltip('Kalender verwalten'), findsOneWidget);
    expect(find.byTooltip('Mein Konto'), findsOneWidget);
  });

  testWidgets('joins family and opens separate shared calendar', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Einladungscode'),
      'a' * 32,
    );
    await tester.tap(find.text('Mit Code beitreten'));
    await tester.pumpAndSettle();
    expect(family.joined, 1);
    expect(find.text('Jeske'), findsOneWidget);
    await tester.tap(find.text('Gemeinsamen Kalender öffnen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lokaler Kalender'), findsNothing);
  });

  testWidgets('shows family members and their roles', (tester) async {
    final (_, family) = await open(tester);
    family.family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Mitglieder (2)'), findsOneWidget);
    expect(find.text('owner@example.test'), findsOneWidget);
    expect(find.text('member@example.test'), findsOneWidget);
    expect(find.text('Besitzer'), findsOneWidget);
    expect(find.text('Mitglied'), findsOneWidget);
  });

  testWidgets('member confirms leaving the shared calendar', (tester) async {
    final (_, family) = await open(tester);
    family.family = const Family(
      id: 'family',
      name: 'Jeske',
      ownerId: 'different-owner',
    );
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kalender verlassen'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender verlassen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Kalender verlassen'));
    await tester.pumpAndSettle();
    expect(family.left, 1);
    expect(
      find.widgetWithText(FilledButton, 'Kalender erstellen'),
      findsOneWidget,
    );
    expect(find.text('Du hast den Kalender verlassen.'), findsOneWidget);
  });
}
