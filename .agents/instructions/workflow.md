# Workflow

## Branches

- Use a dedicated branch for work.
- Preferred branch prefixes are `feature/<short-desc>` and `fix/<short-desc>`.

## Commits

- Use Conventional Commits in `type(scope): short summary` format.
- Valid types include `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, and `perf`.
- Keep the subject line within 72 characters.
- Update `CHANGELOG.md` before creating a commit when the change should be reflected in release notes.

## Pull requests

- Keep one PR focused on one logical change.
- PR creation and merge are normally done by the user unless they explicitly delegate that step.
- A completion handoff should include validation results, coverage, lint status, typecheck status, major changed files, and any recommended follow-up.

## Before changing behavior

- Check `guides/README.md` first to find the relevant feature guide.
- Use feature guides such as `guides/DSL_BASICS.md`, `guides/TASK_OUTPUTS.md`, `guides/PARALLEL_PROCESSING.md`, `guides/DEPENDENCY_WAIT.md`, and `guides/MONITORING_UI.md` before changing semantics in those areas.

## Release preparation

- Record shipped changes in `CHANGELOG.md`, starting from `## [Unreleased]` before they are cut into a release section.
- Keep version-related files in sync when preparing a release.

## Review expectations

- Explain why a change is necessary.
- Keep PRs small enough to review without mixing unrelated work.

## Unconfirmed items

- Reviewer assignment rules outside the repository instructions
- Whether release tagging always happens from `main`
