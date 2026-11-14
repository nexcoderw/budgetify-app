import '../../../../core/storage/secure_storage_service.dart';
import '../../application/onboarding_preferences.dart';

class OnboardingStorage implements OnboardingPreferences {
  OnboardingStorage({required SecureStorageService secureStorageService})
    : _secureStorageService = secureStorageService;

  static const _completionKey = 'ingengo.onboarding.completed.v1';
  static const _legacyCompletionKey = 'budgetify.onboarding.completed.v1';

  final SecureStorageService _secureStorageService;

  @override
  Future<bool> hasCompletedOnboarding() async {
    final value =
        await _secureStorageService.read(_completionKey) ??
        await _secureStorageService.read(_legacyCompletionKey);

    return value == 'true';
  }

  @override
  Future<void> markOnboardingCompleted() {
    return _secureStorageService.write(key: _completionKey, value: 'true');
  }
}
