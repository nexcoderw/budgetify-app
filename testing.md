# Testing Rules

## Execution Policy

Do not run formatting, analysis, tests, builds, dependency installation, or the application unless the user explicitly asks. When implementation is complete, provide the exact commands for the user to run.

Recommended validation order:

```bash
flutter pub get
dart format lib test
flutter analyze
flutter test
```

Platform builds are separate checks:

```bash
flutter build apk
flutter build ios
flutter build web
```

Run only the targets relevant to the change.

## Test Organization

- Mirror the `lib` path under `test`.
- Name files with the `_test.dart` suffix.
- Keep tests deterministic and independent of real network services.
- Use fakes or injected clients for authentication and API behavior.
- Never use production credentials or real customer data in fixtures.

## Coverage Expectations

- Model tests cover parsing, serialization, nullability, and malformed input.
- Service tests cover request construction, authorization, success responses, and safe error mapping.
- Widget tests cover primary states and user-visible behavior.
- Navigation tests verify the post-authentication destination and back-stack behavior.
- A regression fix should include a test that fails without the fix when practical.

## Feature Removal

- Delete tests that exist only for the removed feature.
- Update shared tests that referenced the removed navigation or page.
- Confirm no test imports deleted source files.
- Preserve auth and shared-infrastructure tests unless their behavior truly changed.

## Reporting

State clearly which checks were run and their results. If checks were not run, say so and provide commands rather than implying validation succeeded.
