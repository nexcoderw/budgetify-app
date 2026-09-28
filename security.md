# Security Rules

Security requirements apply to Dart code, platform configuration, assets, logs, documentation, and commits.

## Secrets and Environment Values

- Never commit `.env`, `.env.production`, access tokens, refresh tokens, API keys, private keys, SMTP credentials, or signing credentials.
- Keep only safe placeholders in example environment files.
- Do not print secrets in terminal output, logs, exceptions, screenshots, fixtures, or commit messages.
- Treat Google client secrets and backend service keys as server-side values. The Flutter client may contain only identifiers intended for public clients.
- Rotate a secret immediately if it is exposed in Git history, logs, screenshots, or chat.

## Authentication and Sessions

- Store tokens only through `SecureStorageService`; never use plain preferences or source constants for credentials.
- Clear local session data after logout, unrecoverable refresh failure, or account invalidation.
- Send bearer tokens only to the configured Budgetify API origin.
- Never place access or refresh tokens in URLs, query parameters, analytics events, or error messages.
- Do not weaken authentication checks to simplify local development.

## Network Requests

- Production API traffic must use HTTPS with a valid certificate.
- Centralize requests through `ApiClient` and endpoint paths through feature route files.
- Apply explicit timeouts when introducing long-running requests.
- Convert transport failures into safe user-facing messages without exposing response headers, stack traces, or server internals.
- Validate uploaded file type and size before sending data, and let the server validate them again.

## User Data

- Collect and display only data required for the active flow.
- Avoid retaining financial or identity data in widget logs, debug output, or unencrypted caches.
- Never expose another user's data through shared state or incorrectly reused controllers.
- Redact email addresses, IDs, balances, and tokens from diagnostic output whenever they are not required.

## Platform Configuration

- Add native permissions only when a shipped feature requires them.
- Include a clear user-facing usage description for every sensitive iOS permission.
- Restrict Android intent filters and iOS URL schemes to the exact supported routes.
- Remove permissions, deep links, and plugins when their owning feature is deleted.

## Review Checklist

- No secrets or real credentials are present in the diff.
- Authentication tokens use secure storage.
- API calls use the centralized client and configured base URL.
- Errors shown to users contain no sensitive implementation details.
- New dependencies are maintained, necessary, and minimally privileged.
- Native permissions match actual application behavior.
