# Folder Structure

Budgetify uses a feature-first Flutter structure. Code belongs to the feature that owns the behavior; reusable infrastructure belongs in `core`.

## Current Structure

```text
lib/
├── main.dart
├── app/
│   └── app.dart
├── core/
│   ├── config/
│   ├── models/
│   ├── network/
│   ├── storage/
│   ├── theme/
│   └── widgets/
└── features/
    ├── auth/
    │   ├── application/
    │   ├── data/
    │   │   ├── models/
    │   │   ├── routes/
    │   │   └── services/
    │   └── presentation/
    │       ├── pages/
    │       └── widgets/
    ├── home/
    │   └── presentation/
    │       ├── pages/
    │       └── widgets/
    └── users/
        └── data/
            ├── routes/
            └── services/
```

Platform folders such as `android`, `ios`, `web`, `macos`, `linux`, and `windows` contain platform integration only. Do not place product logic in them.

## Layer Responsibilities

### Presentation

- Pages compose complete screens.
- Widgets are small, reusable UI elements.
- Presentation code may call application services but must not construct raw HTTP requests.
- Keep navigation decisions close to the owning presentation flow.

### Application

- Services coordinate business operations, authentication state, and data flow.
- Application code depends on data services through clear constructor parameters.
- Do not place visual state, colors, or widgets in this layer.

### Data

- `models` parse and serialize API data.
- `routes` contain endpoint paths only.
- `services` execute requests and translate responses into models.
- Never duplicate endpoint strings in pages or widgets.

### Core

- `core` is reserved for reusable, feature-neutral infrastructure.
- A component used by only one feature remains inside that feature.
- Do not move code into `core` merely to shorten imports.

## Adding a Feature

Create only the directories the feature needs:

```text
lib/features/<feature>/
├── application/
├── data/
│   ├── models/
│   ├── routes/
│   └── services/
└── presentation/
    ├── pages/
    └── widgets/
```

Tests mirror the source path under `test/`.

## Removing a Feature

Remove the complete dependency chain:

1. Navigation destinations and imports.
2. Presentation pages and widgets.
3. Application services.
4. Data models, routes, and API services.
5. Feature-specific tests and assets.
6. Unused packages and native permissions.
7. Deep links or platform registrations owned by the feature.

Authentication support must not be removed merely because it is stored under another feature. The `users` client currently supports authenticated profile completion and account deletion.
