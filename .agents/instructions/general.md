# General

## Core behavior

- Respond to repository collaborators in Japanese, even though these agent resource files are written in English.
- Interpret user instructions literally and keep changes scoped to the requested task.
- Ask for clarification before making risky, ambiguous, or behavior-changing edits.
- Prefer existing repository conventions over personal defaults.

## Always do

- Read the relevant repository context before editing.
- Keep changes focused and avoid unrelated cleanup.
- Report what changed, what was validated, and any unresolved points when finishing work.

## Do not do

- Do not create unrelated refactors while working on a user request.
- Do not assume undocumented behavior when repository sources do not confirm it.
- Do not treat generated signatures in `sig/generated/` as the primary editing surface.

## Communication

- Use concise Japanese in user-facing chat.
- State uncertainty explicitly instead of presenting guesses as facts.

## Unconfirmed items

- Additional organization-wide communication rules beyond this repository
