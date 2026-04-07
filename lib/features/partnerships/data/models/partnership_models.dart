class PartnerUser {
  const PartnerUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    required this.avatarUrl,
  });

  factory PartnerUser.fromJson(Map<String, dynamic> json) {
    return PartnerUser(
      id: json['id'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      fullName: json['fullName'] as String?,
      email: json['email'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }

  final String id;
  final String? firstName;
  final String? lastName;
  final String? fullName;
  final String email;
  final String? avatarUrl;
}

enum PartnershipStatus { pending, accepted, revoked }

extension PartnershipStatusX on PartnershipStatus {
  String get apiValue => switch (this) {
    PartnershipStatus.pending => 'PENDING',
    PartnershipStatus.accepted => 'ACCEPTED',
    PartnershipStatus.revoked => 'REVOKED',
  };

  String get label => switch (this) {
    PartnershipStatus.pending => 'Pending',
    PartnershipStatus.accepted => 'Accepted',
    PartnershipStatus.revoked => 'Revoked',
  };

  static PartnershipStatus fromApiValue(String value) => switch (value) {
    'PENDING' => PartnershipStatus.pending,
    'ACCEPTED' => PartnershipStatus.accepted,
    'REVOKED' => PartnershipStatus.revoked,
    _ => PartnershipStatus.pending,
  };
}

class Partnership {
  const Partnership({
    required this.id,
    required this.status,
    required this.inviteeEmail,
    required this.isOwner,
    required this.owner,
    required this.partner,
    required this.expiresAt,
    required this.createdAt,
  });

  factory Partnership.fromJson(Map<String, dynamic> json) {
    return Partnership(
      id: json['id'] as String,
      status: PartnershipStatusX.fromApiValue(json['status'] as String),
      inviteeEmail: json['inviteeEmail'] as String,
      isOwner: json['isOwner'] as bool? ?? false,
      owner: PartnerUser.fromJson(json['owner'] as Map<String, dynamic>),
      partner: (json['partner'] as Map<String, dynamic>?) == null
          ? null
          : PartnerUser.fromJson(json['partner'] as Map<String, dynamic>),
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
    );
  }

  final String id;
  final PartnershipStatus status;
  final String inviteeEmail;
  final bool isOwner;
  final PartnerUser owner;
  final PartnerUser? partner;
  final DateTime expiresAt;
  final DateTime createdAt;
}

class InviteInfo {
  const InviteInfo({
    required this.partnershipId,
    required this.inviteeEmail,
    required this.ownerFirstName,
    required this.ownerLastName,
    required this.ownerFullName,
    required this.ownerAvatarUrl,
    required this.expiresAt,
  });

  factory InviteInfo.fromJson(Map<String, dynamic> json) {
    return InviteInfo(
      partnershipId: json['partnershipId'] as String,
      inviteeEmail: json['inviteeEmail'] as String,
      ownerFirstName: json['ownerFirstName'] as String?,
      ownerLastName: json['ownerLastName'] as String?,
      ownerFullName: json['ownerFullName'] as String?,
      ownerAvatarUrl: json['ownerAvatarUrl'] as String?,
      expiresAt: DateTime.parse(json['expiresAt'] as String).toLocal(),
    );
  }

  final String partnershipId;
  final String inviteeEmail;
  final String? ownerFirstName;
  final String? ownerLastName;
  final String? ownerFullName;
  final String? ownerAvatarUrl;
  final DateTime expiresAt;
}
