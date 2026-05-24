# Coding Style

## Primary sources of truth

- `.rubocop.yml` for Ruby style, complexity, and naming constraints
- `Steepfile`, `rbs_collection.yaml`, and inline RBS usage for type-checking expectations
- `.github/copilot-instructions.md` for repository-specific design and testing rules

## Mechanical style constraints

- Ruby string literals use double quotes.
- RuboCop line length is capped at 120 characters.
- The repository excludes `examples/**/*` from the root RuboCop config because the example app validates itself separately.

## Design rules

- Keep code small and focused on a single responsibility.
- Prefer composable behavior over large monolithic methods.
- Favor immutable workflow inputs through `Arguments`.
- Use `Output` as the main way to communicate task side effects and downstream data.
- Preserve clear boundaries between `Workflow`, `Task`, and `Runner`.
- Avoid breaking public APIs without a documented migration or deprecation path.

## Type and signature rules

- Prefer `rbs-inline` comments in implementation files when type information changes.
- Do not edit generated `.rbs` files or `sig/` artifacts directly unless maintainers explicitly approve it.

## Test-adjacent implementation rules

- Add only the code necessary for the requested behavior and its directly related fixes.
- Reuse existing helpers and patterns before adding new abstractions.
- Comment code only when the behavior is non-obvious.
- Do not change established naming conventions without approval.

## Unconfirmed items

- Any additional hand-written naming rules beyond Ruby conventions and RuboCop enforcement
