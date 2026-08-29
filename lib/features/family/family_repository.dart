import '../calendar/calendar_repository.dart';

class Family {
  const Family({required this.id, required this.name, required this.ownerId});
  final String id;
  final String name;
  final String ownerId;
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
  });

  final String id;
  final String email;
  final bool isOwner;
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
  Future<FamilyInvitation> invite(Family family);
  Future<List<FamilyInvitation>> invitations(Family family);
  Future<void> revokeInvitation(String code);
  Future<void> leaveFamily(Family family);
  CalendarRepository calendar(Family family);
}
