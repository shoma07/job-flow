# Testing

## Required validation

- Every functional change must include new or updated specs that cover the changed behavior.
- Root repository changes must pass:
  - `bundle exec rake spec`
  - `bundle exec rake lint`
  - `bundle exec rake typecheck`
- Root coverage must remain at `100%` line coverage and `100%` branch coverage.

## Example app validation

- If a change touches `examples/rails_8_1/`, also run inside that directory:
  - `bundle exec rake spec`
  - `bundle exec rake lint`
  - `bundle exec rake typecheck`
- Example app coverage must also stay at `100%` line coverage and `100%` branch coverage.

## Validation scope

- If the change only touches root library, engine, guides, or specs outside `examples/rails_8_1/`, run the root validation set.
- If the change touches both root code and `examples/rails_8_1/`, run both validation sets.
- If the change alters behavior, update the relevant guide examples as well as tests.

## Test-writing rules

- Use `bundle exec rake spec`, not `bundle exec rspec`.
- Define a named subject with `subject(:name)`.
- Keep `describe` / `context` nesting at three levels or fewer.
- Prefer one expectation per example unless a matcher like `have_attributes` or a combined matcher makes the assertion a single behavior check.
- Test through public APIs only; do not use `instance_variable_set`, `instance_variable_get`, or similar reflection in specs.
- Keep `let` usage lean and split contexts when conditions differ.

## Completion rule

- Do not report a code change as ready until the required validation commands for the touched surfaces have succeeded.

## Reference material

- Use `guides/TESTING_STRATEGY.md` for testing guidance beyond the mandatory checks.
- Use `guides/MONITORING_UI.md` and feature-specific guides when behavior-oriented expectations need clarification.

## Unconfirmed items

- Whether any additional external CI jobs run outside the repository-local Rake tasks
