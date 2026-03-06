class AuthApiRoutes {
  const AuthApiRoutes._();

  static const instance = AuthApiRoutes._();

  static const String base = '/api/v1/auth';

  String get google => '$base/google';

  String get refresh => '$base/refresh';

  String get logout => '$base/logout';

  String get me => '$base/me';
}
