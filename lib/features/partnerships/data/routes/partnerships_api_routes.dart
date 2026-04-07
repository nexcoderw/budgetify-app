class PartnershipsApiRoutes {
  const PartnershipsApiRoutes._();

  static const instance = PartnershipsApiRoutes._();

  static const String _base = '/api/v1/partnerships';

  String get mine => '$_base/mine';

  String get invite => '$_base/invite';

  String get accept => '$_base/accept';

  String get inviteInfo => '$_base/invite-info';
}
