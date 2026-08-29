import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../calendar/calendar_repository.dart';
import '../calendar/firestore_calendar_repository.dart';
import 'family_repository.dart';

String familyError(Object error) {
  if (error is FamilyFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Kein Zugriff. Bitte bestätige deine E-Mail und aktualisiere den Kontostatus. Falls das erledigt ist, müssen die Firestore-Regeln eingerichtet werden.',
      'unavailable' || 'deadline-exceeded' => 'Keine Serververbindung. Bitte prüfe das Internet und versuche es erneut.',
      'failed-precondition' || 'not-found' => 'Die Familiendatenbank ist noch nicht bereit. Bitte die Firestore-Einrichtung prüfen.',
      _ => 'Die Familienanfrage ist fehlgeschlagen. Bitte erneut versuchen.',
    };
  }
  return 'Die Familienanfrage ist fehlgeschlagen. Bitte erneut versuchen.';
}

class FirestoreFamilyRepository implements FamilyRepository {
  FirestoreFamilyRepository(this.db, this.auth);
  final FirebaseFirestore db;
  final FirebaseAuth auth;

  String _uid() {
    final user = auth.currentUser;
    if (user == null || !user.emailVerified) {
      throw const FamilyFailure(
        'Bitte melde dich mit bestätigter E-Mail-Adresse an.',
      );
    }
    return user.uid;
  }

  String _email() {
    final email = auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const FamilyFailure('Für dieses Konto fehlt eine E-Mail-Adresse.');
    }
    return email;
  }

  void _checkSession(String uid) {
    if (_uid() != uid) {
      throw const FamilyFailure(
        'Das Konto hat sich geändert. Bitte öffne die Familienansicht erneut.',
      );
    }
  }

  @override
  bool canInvite(Family family) => auth.currentUser?.uid == family.ownerId;

  Family _family(String id, Map<String, dynamic> data) => Family(
    id: id,
    name: data['name'] as String,
    ownerId: data['ownerId'] as String,
  );

  @override
  Future<Family?> loadFamily() async {
    final uid = _uid();
    final membership = await db
        .doc('memberships/$uid')
        .get(const GetOptions(source: Source.server));
    _checkSession(uid);
    if (!membership.exists) return null;
    final id = membership.data()!['familyId'] as String;
    final result = await db
        .doc('families/$id')
        .get(const GetOptions(source: Source.server));
    _checkSession(uid);
    if (!result.exists) {
      throw const FamilyFailure('Die Familie konnte nicht gefunden werden.');
    }
    final family = _family(id, result.data()!);
    await _ensureMemberProfile(family, uid);
    return family;
  }

  Future<void> _ensureMemberProfile(Family family, String uid) async {
    final email = _email();
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final membershipRef = db.doc('memberships/$uid');
      final profileRef = db.doc('families/${family.id}/members/$uid');
      final membership = await tx.get(membershipRef);
      final profile = await tx.get(profileRef);
      if (profile.exists) return;
      final joinedAt = membership.data()?['joinedAt'];
      if (joinedAt is! Timestamp) {
        throw const FamilyFailure(
          'Die Familienmitgliedschaft ist unvollständig.',
        );
      }
      tx.set(profileRef, {
        'email': email,
        'role': family.ownerId == uid ? 'owner' : 'member',
        'joinedAt': joinedAt,
      });
    });
    _checkSession(uid);
  }

  @override
  Future<Family> createFamily(String name) async {
    final uid = _uid();
    name = name.trim();
    if (name.isEmpty || name.length > 80) {
      throw const FamilyFailure(
        'Bitte einen Familiennamen mit 1 bis 80 Zeichen eingeben.',
      );
    }
    final ref = db.collection('families').doc();
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final member = db.doc('memberships/$uid');
      if ((await tx.get(member)).exists) {
        throw const FamilyFailure(
          'Du gehörst bereits zu einer Familie. Bitte die Ansicht aktualisieren.',
        );
      }
      tx.set(ref, {
        'name': name,
        'ownerId': uid,
        'timeZone': 'Europe/Berlin',
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(member, {
        'familyId': ref.id,
        'invitationId': null,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.set(ref.collection('members').doc(uid), {
        'email': _email(),
        'role': 'owner',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    _checkSession(uid);
    return Family(id: ref.id, name: name, ownerId: uid);
  }

  @override
  Future<Family> joinFamily(String code) async {
    final uid = _uid();
    code = code.trim().toLowerCase();
    if (!RegExp(r'^[a-f0-9]{32}$').hasMatch(code)) {
      throw const FamilyFailure(
        'Bitte den vollständigen 32-stelligen Einladungscode eingeben.',
      );
    }
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final member = db.doc('memberships/$uid');
      final invite = db.doc('invitations/$code');
      final membership = await tx.get(member);
      final snapshot = await tx.get(invite);
      if (membership.exists) {
        throw const FamilyFailure('Du gehörst bereits zu einer Familie.');
      }
      final data = snapshot.data();
      if (data == null ||
          data['acceptedBy'] != null ||
          !(data['expiresAt'] as Timestamp).toDate().isAfter(DateTime.now())) {
        throw const FamilyFailure(
          'Dieser Einladungscode ist ungültig, abgelaufen oder bereits verwendet.',
        );
      }
      tx.set(member, {
        'familyId': data['familyId'],
        'invitationId': code,
        'joinedAt': FieldValue.serverTimestamp(),
      });
      tx.update(invite, {
        'acceptedBy': uid,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      tx.set(db.doc('families/${data['familyId']}/members/$uid'), {
        'email': _email(),
        'role': 'member',
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
    _checkSession(uid);
    return (await loadFamily())!;
  }

  @override
  Future<List<FamilyMember>> members(Family family) async {
    final uid = _uid();
    final result = await db
        .collection('families/${family.id}/members')
        .get(const GetOptions(source: Source.server));
    _checkSession(uid);
    final members = result.docs.map((item) {
      final data = item.data();
      return FamilyMember(
        id: item.id,
        email: data['email'] as String,
        isOwner: data['role'] == 'owner',
      );
    }).toList();
    members.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.email.toLowerCase().compareTo(b.email.toLowerCase());
    });
    return members;
  }

  @override
  Future<FamilyInvitation> invite(Family family) async {
    final uid = _uid();
    if (family.ownerId != uid) {
      throw const FamilyFailure(
        'Nur die Person, die die Familie erstellt hat, kann einladen.',
      );
    }
    final code = secureCode();
    // A little below the rule's 7-day ceiling to tolerate small clock differences.
    final expires = DateTime.now().toUtc().add(const Duration(days: 6));
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final ref = db.doc('invitations/$code');
      if ((await tx.get(ref)).exists) {
        throw const FamilyFailure('Bitte einen neuen Code erzeugen.');
      }
      tx.set(ref, {
        'familyId': family.id,
        'createdAt': FieldValue.serverTimestamp(),
        'expiresAt': Timestamp.fromDate(expires),
        'acceptedBy': null,
        'acceptedAt': null,
      });
    });
    _checkSession(uid);
    return FamilyInvitation(code: code, expiresAt: expires);
  }

  @override
  Future<List<FamilyInvitation>> invitations(Family family) async {
    final uid = _uid();
    if (family.ownerId != uid) return [];
    final result = await db
        .collection('invitations')
        .where('familyId', isEqualTo: family.id)
        .get(const GetOptions(source: Source.server));
    _checkSession(uid);
    final now = DateTime.now();
    final invitations = result.docs
        .where((item) {
          final data = item.data();
          return data['acceptedBy'] == null &&
              (data['expiresAt'] as Timestamp).toDate().isAfter(now);
        })
        .map(
          (item) => FamilyInvitation(
            code: item.id,
            expiresAt: (item.data()['expiresAt'] as Timestamp).toDate(),
          ),
        )
        .toList();
    invitations.sort((a, b) => a.expiresAt.compareTo(b.expiresAt));
    return invitations;
  }

  @override
  Future<void> revokeInvitation(String code) async {
    final uid = _uid();
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final ref = db.doc('invitations/$code');
      await tx.get(ref);
      tx.delete(ref);
    });
    _checkSession(uid);
  }

  @override
  Future<void> leaveFamily(Family family) async {
    final uid = _uid();
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final familyRef = db.doc('families/${family.id}');
      final membershipRef = db.doc('memberships/$uid');
      final profileRef = familyRef.collection('members').doc(uid);
      final currentFamily = await tx.get(familyRef);
      final membership = await tx.get(membershipRef);
      if (!currentFamily.exists ||
          !membership.exists ||
          membership.data()?['familyId'] != family.id) {
        throw const FamilyFailure(
          'Die Familienmitgliedschaft wurde bereits geändert.',
        );
      }
      if (currentFamily.data()?['ownerId'] == uid) {
        throw const FamilyFailure(
          'Als Besitzer kannst du die Familie noch nicht verlassen.',
        );
      }
      tx.delete(profileRef);
      tx.delete(membershipRef);
    });
    _checkSession(uid);
  }

  @override
  CalendarRepository calendar(Family family) => FirestoreCalendarRepository(
    db: db,
    familyId: family.id,
    familyName: family.name,
    uid: _uid(),
    sessionValid: (uid) =>
        auth.currentUser?.uid == uid && auth.currentUser?.emailVerified == true,
  );
}
