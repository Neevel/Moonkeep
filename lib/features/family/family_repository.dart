import '../calendar/calendar_repository.dart';

enum FamilyStatus { active, dissolved }

class Family {
  const Family({
    required this.id,
    required this.name,
    required this.ownerId,
    this.status = FamilyStatus.active,
  });
  final String id;
  final String name;
  final String ownerId;
  final FamilyStatus status;

  bool get isActive => status == FamilyStatus.active;
}

class FamilyInvitation {
  const FamilyInvitation({required this.code, required this.expiresAt});
  final String code;
  final DateTime expiresAt;
}

class FamilyMember {
  const FamilyMember({
    required this.id,
    required this.email,
    required this.isOwner,
    this.displayName,
  });

  final String id;
  final String email;
  final bool isOwner;
  final String? displayName;

  String get displayLabel {
    final name = displayName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    return email.trim().isEmpty ? 'Mitglied' : email;
  }
}

class FamilyFailure implements Exception {
  const FamilyFailure(this.message);
  final String message;
}

abstract interface class FamilyRepository {
  bool canInvite(Family family);
  Future<Family?> loadFamily();
  Future<Family> createFamily(String name);
  Future<Family> joinFamily(String code);
  Future<List<FamilyMember>> members(Family family);
  Future<void> updateOwnDisplayName(String displayName);
  Future<FamilyInvitation> invite(Family family);
  Future<List<FamilyInvitation>> invitations(Family family);
  Future<void> revokeInvitation(String code);
  Future<void> leaveFamily(Family family);
  Future<Family> transferOwnership(Family family, String newOwnerId);
  Future<void> dissolveFamily(Family family);
  CalendarRepository calendar(Family family);
}
