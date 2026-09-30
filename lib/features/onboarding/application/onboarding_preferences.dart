abstract interface class OnboardingPreferences {
  Future<bool> hasCompletedOnboarding();

  Future<void> markOnboardingCompleted();
}
