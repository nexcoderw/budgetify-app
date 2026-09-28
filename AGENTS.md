# Budgetify Flutter Agent Rules

These instructions apply to the entire `app` project.

Before changing code, read the rule documents relevant to the task:

- `folder-structure.md` for ownership and dependency boundaries.
- `coding-standards.md` for Dart, Flutter, UI, and API conventions.
- `security.md` for secrets, authentication, storage, and network safety.
- `environment.md` for runtime configuration.
- `testing.md` for validation expectations.
- `git.md` before staging or proposing commits.

## Required Workflow

1. Preserve unrelated user changes and inspect the working tree before editing.
2. Keep changes inside this Flutter project unless the user explicitly expands the scope.
3. Do not run formatting, analysis, tests, builds, dependency installation, or application processes unless the user explicitly asks. Provide the exact commands for the user to run.
4. Use feature-first architecture and remove stale imports, routes, dependencies, tests, and platform configuration when deleting a feature.
5. Never read, print, modify, or commit real secrets from `.env` files.
6. Follow `git.md`: every changed file must have its own commit and commit message.

When instructions conflict, the user's current request takes precedence.
