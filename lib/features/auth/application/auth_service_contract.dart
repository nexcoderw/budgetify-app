import '../data/models/auth_session.dart';
import '../data/models/auth_user.dart';
import '../data/models/email_initiate_response.dart';
import '../data/models/password_auth_models.dart';

abstract class AuthServiceContract {
  Future<void> ensureInitialized();

  // ── Google OAuth ────────────────────────────────────────────────────────────

  Future<AuthSession> signInWithGoogle();

  Future<AuthSession> signInWithGoogleIdToken(String idToken);

  // ── Email OTP ───────────────────────────────────────────────────────────────

  /// Step 1: submit email address.
  /// Returns [EmailInitiateResponse] with [action] "login" or "register"
  /// so the caller can display the appropriate OTP screen copy.
  Future<EmailInitiateResponse> initiateEmailAuth(String email);

  /// Step 2: submit the 4-digit OTP received by email.
  /// Returns a full [AuthSession] on success.
  Future<AuthSession> verifyEmailOtp(String email, String otp);

  // ── Password authentication ───────────────────────────────────────────────

  Future<PasswordStatus> getPasswordStatus(String email);

  Future<PasswordChallenge> requestPasswordChallenge(String email);

  Future<PasswordSetupGrant> verifyPasswordChallenge(String email, String otp);

  Future<void> setPassword({
    required String grantToken,
    required String password,
    required String confirmPassword,
  });

  Future<AuthSession> signInWithPassword({
    required String email,
    required String password,
  });

  /// Updates the authenticated user's profile names and returns the refreshed
  /// user payload from the API.
  Future<AuthUser> updateCurrentUserNames({
    required String firstName,
    required String lastName,
  });

  Future<AuthUser> requestCurrentUserDeletion();

  // ── Session management ──────────────────────────────────────────────────────

  Future<AuthUser?> restoreAuthenticatedUser();

  Future<AuthSession> refreshSession();

  Future<void> logout();

  Future<void> clearSession();
}
