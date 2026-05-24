# Tech Stack

## Languages and frameworks

- Ruby `>= 3.1.0` for the gem runtime
- Rails and ActiveJob for the workflow runtime and monitoring engine integration
- Solid Queue in the example app for asynchronous execution scenarios
- SQLite in local and example-app development flows
- RBS Inline plus Steep for type checking
- RSpec for tests
- RuboCop with repository plugins for linting
- SimpleCov for 100% line and branch coverage enforcement

## Primary commands

- Root validation:
  - `bundle exec rake spec`
  - `bundle exec rake lint`
  - `bundle exec rake typecheck`
- Useful root helpers:
  - `bundle exec rake lint:fix`
  - `bundle exec rake lint:fixall`
  - `bundle exec rake rbs:install`
  - `bundle exec rake rbs:update`
  - `bundle exec rake rbs:inline`
- Example app validation from `examples/rails_8_1/`:
  - `bundle exec rake spec`
  - `bundle exec rake lint`
  - `bundle exec rake typecheck`

## Architecture summary

- `Workflow`, `Task`, `Runner`, `Arguments`, `Context`, and `Output` form the core execution model.
- Queue adapters isolate runtime-specific job lookup and persistence behavior.
- Monitoring code lives under `lib/job_workflow/monitoring/` and is rendered through the Rails engine in `app/`.
- The example Rails app is the main integration harness for real ActiveJob and Solid Queue behavior.

## Important command rule

- Use the repository Rake tasks instead of calling `rspec`, `rubocop`, or `steep` directly for final validation.
