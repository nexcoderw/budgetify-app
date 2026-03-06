import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';

abstract class AuthServiceContract {
  Future<AuthSession> signInWithGoogle();

  Future<AuthUser?> restoreAuthenticatedUser();

  Future<AuthSession> refreshSession();

  Future<void> logout();

  Future<void> clearSession();
}
