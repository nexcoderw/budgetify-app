# Budgetify App

Budgetify App is the Flutter client for the Budgetify platform. It is designed
for users who want the same account, finance data, and planning flows available
from a mobile-first experience.

## What This Project Is

- A Flutter application connected to the Budgetify API
- Built for cross-platform delivery
- Focused on fast authentication, finance logging, and personal planning flows

## Current Product Areas

- Authentication
- Home shell
- Income flows
- Todo flows
- User profile flows

The app uses the same backend domain model as the web client and is intended to
stay consistent with the Budgetify design system.

## Stack

- Flutter
- Dart
- flutter_dotenv
- flutter_secure_storage
- google_sign_in
- http
- image_picker
- toastification

## Supported Targets

This project contains Flutter platform folders for:

- Android
- iOS
- Web
- macOS
- Windows
- Linux

## Local Development

1. Install Flutter dependencies:

```bash
flutter pub get
```

2. Create the runtime env file:

```bash
cp .env.example .env
```

3. Update the environment values in `.env`.

Important keys:

- `API_BASE_URL`
- `API_BASE_URL_MOBILE`
- `API_BASE_URL_WEB`
- `GOOGLE_SERVER_CLIENT_ID`
- `GOOGLE_CLIENT_ID`
- `GOOGLE_IOS_CLIENT_ID` when needed

4. Run the application:

```bash
flutter run
```

## Common Commands

```bash
flutter pub get
flutter run
flutter test
flutter analyze
flutter build apk
flutter build ios
flutter build web
```

## Configuration Notes

- The app resolves API URLs through `AppEnv`.
- Native and web targets can use different API base URLs.
- Authentication depends on properly configured Google client IDs.
- The app shares the Budgetify backend contract with the `api` project.

## Related Projects

- Backend API: `../api`
- Web client: `../web`

For local development, start the API first, then run the Flutter app against
that local backend.
