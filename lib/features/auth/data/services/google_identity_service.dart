import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../../core/config/app_env.dart';

class GoogleIdentityException implements Exception {
  const GoogleIdentityException({
    required this.message,
    this.isCanceled = false,
  });

  final String message;
  final bool isCanceled;

  @override
  String toString() => message;
}

class GoogleIdentityService {
  GoogleIdentityService({GoogleSignIn? googleSignIn})
    : _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  final GoogleSignIn _googleSignIn;
  bool _isInitialized = false;

  Future<String> getIdToken() async {
    try {
      await _ensureInitialized();
      await _googleSignIn.signOut();
      final account = await _googleSignIn.authenticate(
        scopeHint: const ['email', 'profile', 'openid'],
      );
      final idToken = account.authentication.idToken;

      if (idToken == null || idToken.isEmpty) {
        throw const GoogleIdentityException(
          message:
              'Google sign-in did not return an ID token. Check your server client configuration.',
        );
      }

      return idToken;
    } on GoogleSignInException catch (error) {
      switch (error.code) {
        case GoogleSignInExceptionCode.canceled:
          throw const GoogleIdentityException(
            message: 'Google sign-in was canceled.',
            isCanceled: true,
          );
        case GoogleSignInExceptionCode.interrupted:
          throw const GoogleIdentityException(
            message: 'Google sign-in was interrupted. Please try again.',
          );
        case GoogleSignInExceptionCode.uiUnavailable:
          throw const GoogleIdentityException(
            message: 'Google sign-in is unavailable on this device right now.',
          );
        case GoogleSignInExceptionCode.clientConfigurationError:
          throw const GoogleIdentityException(
            message:
                'Google sign-in client configuration is incomplete for this platform.',
          );
        default:
          throw GoogleIdentityException(
            message: error.description ?? 'Unable to continue with Google.',
          );
      }
    } on PlatformException catch (error) {
      final message = error.message ?? error.code;

      if (message.contains('No active configuration') ||
          message.contains('GIDClientID')) {
        throw const GoogleIdentityException(
          message:
              'Google sign-in is not configured correctly for iOS. Add GIDClientID and GIDServerClientID in Info.plist and rebuild the app.',
        );
      }

      throw GoogleIdentityException(message: message);
    }
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await _googleSignIn.signOut();
  }

  Future<void> _ensureInitialized() async {
    if (_isInitialized) {
      return;
    }

    await _googleSignIn.initialize(
      clientId: _resolveClientId(),
      serverClientId: AppEnv.googleServerClientId,
    );

    _isInitialized = true;
  }

  String? _resolveClientId() {
    if (kIsWeb) {
      return AppEnv.optional('GOOGLE_CLIENT_ID');
    }

    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return AppEnv.optional('GOOGLE_IOS_CLIENT_ID');
    }

    return null;
  }
}
