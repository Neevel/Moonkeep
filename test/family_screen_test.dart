import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonkeep/app.dart';
import 'package:moonkeep/features/account/auth_repository.dart';
import 'package:moonkeep/features/calendar/calendar_repository.dart';
import 'package:moonkeep/features/calendar/calendar_store.dart';
import 'package:moonkeep/features/family/family_repository.dart';
import 'package:moonkeep/features/family/firestore_family_repository.dart';

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
  int created = 0,
      joined = 0,
      invited = 0,
      revoked = 0,
      left = 0,
      transferred = 0,
      dissolved = 0;
  FamilyFailure? transferFailure;
  FamilyFailure? joinFailure;
  Completer<void>? pendingJoin;
  @override
  bool canInvite(Family value) => value.ownerId == 'owner';
  @override
  Future<Family?> loadFamily() async {
    if (family?.isActive == false) {
      family = null;
      return null;
    }
    return family;
  }

  @override
  Future<Family> createFamily(String name) async {
    created++;
    family = Family(id: 'family', name: name.trim(), ownerId: 'owner');
    return family!;
  }

  @override
  Future<Family> joinFamily(String code) async {
    joined++;
    if (joinFailure != null) throw joinFailure!;
    await pendingJoin?.future;
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
  Future<Family> transferOwnership(Family value, String newOwnerId) async {
    transferred++;
    if (transferFailure != null) throw transferFailure!;
    if (value.ownerId == newOwnerId) {
      throw const FamilyFailure('Du besitzt diesen Kalender bereits.');
    }
    family = Family(id: value.id, name: value.name, ownerId: newOwnerId);
    familyMembers = [
      for (final member in familyMembers)
        FamilyMember(
          id: member.id,
          email: member.email,
          isOwner: member.id == newOwnerId,
        ),
    ];
    return family!;
  }

  @override
  Future<void> dissolveFamily(Family value) async {
    if (value.ownerId != 'owner' || !value.isActive) {
      throw const FamilyFailure(
        'Nur der aktuelle Besitzer kann diesen Kalender auflösen.',
      );
    }
    dissolved++;
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
  test('maps Firebase failures to short user-facing calendar messages', () {
    expect(
      familyError(
        FirebaseException(plugin: 'firestore', code: 'permission-denied'),
      ),
      'Du hast dafür keine Berechtigung. Bitte prüfe, ob deine E-Mail-Adresse bestätigt ist.',
    );
    expect(
      familyError(FirebaseException(plugin: 'firestore', code: 'unavailable')),
      'Keine Serververbindung. Bitte prüfe das Internet und versuche es erneut.',
    );
    expect(
      familyError(
        FirebaseException(plugin: 'firestore', code: 'failed-precondition'),
      ),
      'Die Kalenderdaten sind momentan nicht verfügbar. Bitte versuche es erneut.',
    );
  });

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
    expect(find.text('Kalender erstellt.'), findsOneWidget);
    await tester.tap(find.text('Einladungscode erzeugen'));
    await tester.pumpAndSettle();
    expect(family.invited, 1);
    expect(find.text('a' * 32), findsOneWidget);
    expect(find.text('Einladung erstellt.'), findsOneWidget);
    await tester.tap(find.text('Widerrufen'));
    await tester.pumpAndSettle();
    expect(family.revoked, 1);
    expect(find.text('a' * 32), findsNothing);
    expect(find.text('Einladung widerrufen.'), findsOneWidget);
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
    expect(find.text('Kalender beigetreten.'), findsOneWidget);
    await tester.tap(find.text('Gemeinsamen Kalender öffnen'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Lokaler Kalender'), findsNothing);
  });

  testWidgets('invalid invitation stays understandable and join is retryable', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    family.joinFailure = const FamilyFailure(
      'Dieser Einladungscode ist ungültig, abgelaufen oder bereits verwendet.',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Einladungscode'),
      'a' * 32,
    );
    await tester.tap(find.text('Mit Code beitreten'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Dieser Einladungscode ist ungültig, abgelaufen oder bereits verwendet.',
      ),
      findsOneWidget,
    );
    expect(find.text('Mit Code beitreten'), findsOneWidget);
  });

  testWidgets('pending join disables duplicate submissions', (tester) async {
    final (_, family) = await open(tester);
    family.pendingJoin = Completer<void>();
    await tester.enterText(
      find.widgetWithText(TextField, 'Einladungscode'),
      'a' * 32,
    );
    final joinButton = find.widgetWithText(FilledButton, 'Mit Code beitreten');
    await tester.tap(joinButton);
    await tester.pump();
    expect(joinButton, findsNothing);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    expect(family.joined, 1);
    family.pendingJoin!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Kalender beigetreten.'), findsOneWidget);
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

  testWidgets('owner transfers ownership to an existing member', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    family.family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(
      find.byTooltip('Besitz an member@example.test übertragen'),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Besitz an owner@example.test übertragen'),
      findsNothing,
    );
    await tester.tap(
      find.byTooltip('Besitz an member@example.test übertragen'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Besitz übertragen?'), findsOneWidget);
    expect(
      find.textContaining('Danach bist du normales Mitglied'),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Besitz übertragen'));
    await tester.pumpAndSettle();
    expect(family.transferred, 1);
    expect(family.family!.ownerId, 'member');
    final newOwnerTile = find.ancestor(
      of: find.text('member@example.test'),
      matching: find.byType(ListTile),
    );
    final oldOwnerTile = find.ancestor(
      of: find.text('owner@example.test'),
      matching: find.byType(ListTile),
    );
    expect(
      find.descendant(of: newOwnerTile, matching: find.text('Besitzer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: oldOwnerTile, matching: find.text('Mitglied')),
      findsOneWidget,
    );
    expect(find.text('Besitz übertragen.'), findsOneWidget);
    expect(find.text('Einladungscode erzeugen'), findsNothing);
    expect(find.byIcon(Icons.manage_accounts_outlined), findsNothing);
  });

  testWidgets('normal members cannot transfer ownership', (tester) async {
    final (_, family) = await open(tester);
    family.family = const Family(
      id: 'family',
      name: 'Jeske',
      ownerId: 'different-owner',
    );
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.manage_accounts_outlined), findsNothing);
  });

  testWidgets('ownership transfer failure remains understandable', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    family.family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    family.transferFailure = const FamilyFailure(
      'Das ausgewählte Mitglied gehört nicht mehr zu diesem Kalender.',
    );
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byTooltip('Besitz an member@example.test übertragen'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Besitz übertragen'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Das ausgewählte Mitglied gehört nicht mehr zu diesem Kalender.',
      ),
      findsOneWidget,
    );
    expect(
      find.byTooltip('Besitz an member@example.test übertragen'),
      findsOneWidget,
    );
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
    expect(find.text('Kalender verlassen.'), findsOneWidget);
  });

  testWidgets('only owner sees dissolution and returns to calendar setup', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    family.family = const Family(id: 'family', name: 'Jeske', ownerId: 'owner');
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender auflösen'), findsOneWidget);

    await tester.tap(find.text('Kalender auflösen'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender endgültig auflösen?'), findsOneWidget);
    expect(
      find.text(
        'Der gemeinsame Kalender wird für alle Mitglieder geschlossen und kann danach nicht mehr verwendet werden.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Kalender auflösen'));
    await tester.pumpAndSettle();

    expect(family.dissolved, 1);
    expect(
      find.widgetWithText(FilledButton, 'Kalender erstellen'),
      findsOneWidget,
    );
    expect(find.text('Kalender aufgelöst.'), findsOneWidget);
  });

  testWidgets('normal member does not see calendar dissolution', (
    tester,
  ) async {
    final (_, family) = await open(tester);
    family.family = const Family(
      id: 'family',
      name: 'Jeske',
      ownerId: 'different-owner',
    );
    await tester.tap(find.text('Aktualisieren'));
    await tester.pumpAndSettle();
    expect(find.text('Kalender auflösen'), findsNothing);
  });

  testWidgets('dissolved calendar loads as no active calendar', (tester) async {
    final auth = FakeAuth(
      const AccountIdentity(email: 'test@example.test', emailVerified: true),
    );
    final family = FakeFamily()
      ..family = const Family(
        id: 'family',
        name: 'Jeske',
        ownerId: 'owner',
        status: FamilyStatus.dissolved,
      );
    addTearDown(auth.changes.close);
    await tester.pumpWidget(
      MoonkeepApp(auth: auth, family: family, autoOpenCalendar: false),
    );
    await tester.pumpAndSettle();

    expect(family.family, isNull);
    expect(
      find.widgetWithText(FilledButton, 'Kalender erstellen'),
      findsOneWidget,
    );
    expect(find.text('Jeske'), findsNothing);
  });
}
