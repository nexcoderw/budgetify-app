class UsersApiRoutes {
  const UsersApiRoutes._();

  static const instance = UsersApiRoutes._();

  static const String base = '/api/v1/users';

  String get me => '$base/me';
}
