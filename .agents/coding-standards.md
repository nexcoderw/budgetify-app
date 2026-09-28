# Coding Standards

## Dart

- Follow `flutter_lints` and keep `flutter analyze` free of errors and warnings.
- Use `dart format` for canonical formatting.
- Prefer `const` constructors and widgets when every argument is compile-time constant.
- Use `final` by default; introduce mutable state only when behavior requires it.
- Give private implementation details a leading underscore.
- Avoid `dynamic` unless an external package forces it and no safe public type is available.
- Keep methods focused. Extract cohesive widgets or services instead of growing large build methods.
- Do not suppress analyzer rules without a narrow comment explaining why.

## Flutter UI

- Use `AppTheme` and `AppColors`; do not create competing theme systems inside features.
- Reuse established shared widgets such as `GlassPanel` and `AppToast` when they match the interaction.
- Support narrow mobile screens without horizontal overflow.
- Keep touch targets at least 44 logical pixels.
- Add semantic labels and tooltips to icon-only actions.
- Handle long text, keyboard insets, loading, empty, error, and disabled states.
- Use `SafeArea` for full-screen layouts that touch device edges.
- Keep animations purposeful, short, and safe when a widget is disposed.

## State and Lifecycle

- Keep transient UI state in the owning widget unless it must be shared.
- Dispose controllers, focus nodes, subscriptions, and listeners.
- Check `mounted` after an asynchronous gap before using `context` or calling `setState`.
- Do not start API requests from `build`.
- Avoid hidden global mutable state.

## API Integration

- Define endpoint paths under `data/routes`.
- Execute HTTP operations through `ApiClient` or a feature data service.
- Parse untrusted JSON defensively into typed models.
- Keep authorization and session resolution in application or data services, not widgets.
- Convert technical failures into clear, safe messages at the presentation boundary.

## Naming

- Files and directories: `snake_case`.
- Classes, enums, and extensions: `UpperCamelCase`.
- Variables, methods, and parameters: `lowerCamelCase`.
- Boolean names should read as conditions, such as `isLoading`, `hasSession`, or `canSubmit`.
- Page classes end in `Page`; reusable visual components use a descriptive widget name.

## Dependencies

- Add a package only when the platform SDK or current dependencies cannot reasonably provide the behavior.
- Prefer actively maintained packages with compatible licenses and platform support.
- Remove packages and generated registrations after their last use is removed.
- Keep dependency versions explicit in `pubspec.yaml` and commit the resulting `pubspec.lock` separately.
