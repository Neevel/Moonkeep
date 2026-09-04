import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../calendar/calendar_repository.dart';
import '../calendar/firestore_calendar_repository.dart';
import 'family_repository.dart';

String familyError(Object error) {
  if (error is FamilyFailure) return error.message;
  if (error is FirebaseException) {
    return switch (error.code) {
      'permission-denied' => 'Du hast dafür keine Berechtigung. Bitte prüfe, ob deine E-Mail-Adresse bestätigt ist.',
      'unavailable' || 'deadline-exceeded' => 'Keine Serververbindung. Bitte prüfe das Internet und versuche es erneut.',
      'failed-precondition' || 'not-found' => 'Die Kalenderdaten sind momentan nicht verfügbar. Bitte versuche es erneut.',
      _ => 'Die Kalenderaktion ist fehlgeschlagen. Bitte versuche es erneut.',
    };
  }
  return 'Die Kalenderaktion ist fehlgeschlagen. Bitte versuche es erneut.';
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

  String? _displayName() {
    final name = auth.currentUser?.displayName?.trim();
    return name == null || name.isEmpty || name.length > 40 ? null : name;
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
    status: data['status'] == null || data['status'] == 'active'
        ? FamilyStatus.active
        : FamilyStatus.dissolved,
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
    if (!family.isActive) {
      await _clearDissolvedMembership(family, uid);
      return null;
    }
    await _ensureMemberProfile(family, uid);
    return family;
  }

  Future<void> _clearDissolvedMembership(Family family, String uid) async {
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final familyRef = db.doc('families/${family.id}');
      final membershipRef = db.doc('memberships/$uid');
      final profileRef = familyRef.collection('members').doc(uid);
      final currentFamily = await tx.get(familyRef);
      final membership = await tx.get(membershipRef);
      if (!membership.exists) return;
      if (membership.data()?['familyId'] != family.id ||
          currentFamily.data()?['status'] != 'dissolved') {
        throw const FamilyFailure(
          'Die Familienmitgliedschaft wurde bereits geändert.',
        );
      }
      tx.delete(profileRef);
      tx.delete(membershipRef);
    });
    _checkSession(uid);
  }

  Future<void> _ensureMemberProfile(Family family, String uid) async {
    final email = _email();
    final displayName = _displayName();
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final membershipRef = db.doc('memberships/$uid');
      final profileRef = db.doc('families/${family.id}/members/$uid');
      final membership = await tx.get(membershipRef);
      final profile = await tx.get(profileRef);
      if (profile.exists) {
        if (displayName != null &&
            profile.data()?['displayName'] != displayName) {
          tx.update(profileRef, {'displayName': displayName});
        }
        return;
      }
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
        'displayName': ?displayName,
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
        'status': 'active',
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
        'displayName': ?_displayName(),
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
        'displayName': ?_displayName(),
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
        displayName: data['displayName'] as String?,
      );
    }).toList();
    members.sort((a, b) {
      if (a.isOwner != b.isOwner) return a.isOwner ? -1 : 1;
      return a.displayLabel.toLowerCase().compareTo(
        b.displayLabel.toLowerCase(),
      );
    });
    return members;
  }

  @override
  Future<void> updateOwnDisplayName(String displayName) async {
    final uid = _uid();
    displayName = displayName.trim();
    if (displayName.isEmpty || displayName.length > 40) {
      throw const FamilyFailure(
        'Bitte einen Anzeigenamen mit 1 bis 40 Zeichen eingeben.',
      );
    }
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final membershipRef = db.doc('memberships/$uid');
      final membership = await tx.get(membershipRef);
      if (!membership.exists) return;
      final familyId = membership.data()?['familyId'];
      if (familyId is! String) return;
      final familyRef = db.doc('families/$familyId');
      final profileRef = familyRef.collection('members').doc(uid);
      final family = await tx.get(familyRef);
      final profile = await tx.get(profileRef);
      if (!family.exists ||
          family.data()?['status'] == 'dissolved' ||
          !profile.exists) {
        return;
      }
      tx.update(profileRef, {'displayName': displayName});
    });
    _checkSession(uid);
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
      // Missing bearer-code documents are intentionally unreadable. Write the
      // random code directly; a collision becomes an update and is denied by
      // the existing invitation rules.
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
  Future<Family> transferOwnership(Family family, String newOwnerId) async {
    final uid = _uid();
    if (newOwnerId == uid) {
      throw const FamilyFailure('Du besitzt diesen Kalender bereits.');
    }
    final familyRef = db.doc('families/${family.id}');
    final oldOwnerRef = familyRef.collection('members').doc(uid);
    final newOwnerRef = familyRef.collection('members').doc(newOwnerId);
    final newOwnerMembershipRef = db.doc('memberships/$newOwnerId');
    final result = await db.runTransaction((tx) async {
      _checkSession(uid);
      final currentFamily = await tx.get(familyRef);
      final oldOwner = await tx.get(oldOwnerRef);
      final newOwner = await tx.get(newOwnerRef);
      final newOwnerMembership = await tx.get(newOwnerMembershipRef);
      final data = currentFamily.data();
      if (data == null ||
          data['ownerId'] != uid ||
          data['status'] == 'dissolved') {
        throw const FamilyFailure(
          'Der Besitz wurde bereits geändert. Bitte aktualisiere die Ansicht.',
        );
      }
      if (!oldOwner.exists || oldOwner.data()?['role'] != 'owner') {
        throw const FamilyFailure('Die aktuelle Besitzerrolle ist ungültig.');
      }
      if (!newOwner.exists ||
          newOwner.data()?['role'] != 'member' ||
          !newOwnerMembership.exists ||
          newOwnerMembership.data()?['familyId'] != family.id) {
        throw const FamilyFailure(
          'Das ausgewählte Mitglied gehört nicht mehr zu diesem Kalender.',
        );
      }
      tx.update(familyRef, {'ownerId': newOwnerId});
      tx.update(oldOwnerRef, {'role': 'member'});
      tx.update(newOwnerRef, {'role': 'owner'});
      return Family(
        id: family.id,
        name: data['name'] as String,
        ownerId: newOwnerId,
      );
    });
    _checkSession(uid);
    return result;
  }

  @override
  Future<void> dissolveFamily(Family family) async {
    final uid = _uid();
    if (family.ownerId != uid || !family.isActive) {
      throw const FamilyFailure(
        'Nur der aktuelle Besitzer kann diesen Kalender auflösen.',
      );
    }
    final familyRef = db.doc('families/${family.id}');
    final membershipRef = db.doc('memberships/$uid');
    await db.runTransaction((tx) async {
      _checkSession(uid);
      final currentFamily = await tx.get(familyRef);
      final membership = await tx.get(membershipRef);
      final data = currentFamily.data();
      if (data == null ||
          data['ownerId'] != uid ||
          data['status'] == 'dissolved' ||
          !membership.exists ||
          membership.data()?['familyId'] != family.id) {
        throw const FamilyFailure(
          'Der Kalender wurde bereits aufgelöst oder der Besitz wurde geändert.',
        );
      }
      tx.update(familyRef, {'status': 'dissolved'});
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
