# Environment Configuration

Runtime configuration is loaded by `AppEnv` from the project-level `.env` file. Real environment files are local-only and must never be committed.

## Setup

```bash
cp .env.example .env
```

Populate the local file with values appropriate for the target device.

## Supported Variables

```dotenv
APP_NAME=Budgetify
API_BASE_URL=http://127.0.0.1:8000/api/v1
API_BASE_URL_MOBILE=http://192.168.1.42:8000/api/v1
API_BASE_URL_WEB=http://127.0.0.1:8000/api/v1
GOOGLE_SERVER_CLIENT_ID=
GOOGLE_CLIENT_ID=
```

`API_BASE_URL_NATIVE` is also supported as a native override and takes precedence over `API_BASE_URL_MOBILE`.

## Target Behavior

- Web uses `API_BASE_URL_WEB`.
- Native platforms use `API_BASE_URL_NATIVE`, then `API_BASE_URL_MOBILE`, then `API_BASE_URL`.
- Android emulators automatically translate `localhost` and `127.0.0.1` to `10.0.2.2`.
- Physical devices must use an API address reachable from that device, such as the development computer's LAN IP.
- Production builds must use HTTPS endpoints.

## Rules

- Keep `.env` and `.env.production` ignored by Git.
- Store only placeholders in `.env.example`.
- Do not embed server secrets in `--dart-define`; Flutter client values can be extracted from a built application.
- Update `.env.example` and this file when a required client-side variable is added or renamed.
- Keep `/api/v1` handling consistent with `AppEnv`, which normalizes that suffix before route paths are appended.
- Do not access `dotenv.env` outside `AppEnv`; centralize validation and platform resolution there.

## Troubleshooting Connectivity

Verify the selected URL from the same device or emulator running Flutter. A working API on the development computer may still be unreachable from a phone, container, or emulator because each environment has a different network namespace.
