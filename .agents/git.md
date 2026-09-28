# Git Rules

This project uses Conventional Commits and requires one changed file per commit.

## One File per Commit

Every modified, added, renamed, or deleted file must be committed separately. Do not combine generated files, tests, documentation, or source files in one commit.

Use explicit paths:

```bash
git add -- path/to/file.dart
git commit -m "type(scope): concise change"
```

Before each commit, verify the staged scope:

```bash
git diff --cached --name-only
git diff --cached --check
```

The first command must show exactly one file.

## Commit Format

```text
type(scope): imperative summary
```

Allowed types:

- `feat`: user-visible capability.
- `fix`: defect correction.
- `refactor`: structural change with no intended behavior change.
- `style`: visual or formatting-only change.
- `test`: test addition, removal, or correction.
- `docs`: documentation only.
- `chore`: tooling, dependency, generated, or platform maintenance.
- `perf`: measurable performance improvement.
- `build`: build system or packaging change.
- `ci`: continuous-integration change.

Prefer a feature or platform name for the scope, such as `auth`, `home`, `navigation`, `android`, `ios`, `deps`, or `security`.

Examples:

```text
feat(auth): add email OTP verification
style(navigation): compact bottom navigation capsule
refactor(expenses): remove expense API routes
test(home): expect send money landing screen
docs(security): document token storage rules
chore(deps): remove unused image picker package
```

## Commit Quality

- Use an imperative summary: `add`, `remove`, `update`, `prevent`, or `simplify`.
- Keep the subject concise and do not end it with a period.
- Describe the actual file change, not the task number or a vague phrase such as `updates`.
- Never include secrets, tokens, private URLs, customer information, or temporary debugging data.
- Generated files still receive their own commit.
- A deleted file receives a message explaining what was removed.

## Safety

- Inspect `git status --short` before editing and before committing.
- Preserve unrelated user changes.
- Do not use destructive history commands unless the user explicitly requests them.
- Do not amend, rebase, force-push, or rewrite shared history without explicit approval.
- Never commit `.env` or production credentials.
