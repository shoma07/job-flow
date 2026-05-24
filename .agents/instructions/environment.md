# Environment

## Required local tools

- Ruby and Bundler for gem development
- SQLite3 for local development and the example app
- A shell environment that can run the root and example-app Rake tasks

## Root setup

```bash
bin/setup
bundle install
bundle exec rake rbs:install
```

## Example app setup

From `examples/rails_8_1/`:

```bash
bundle install
bundle exec rails db:prepare
bundle exec rake rbs:install
```

## Running the example app

- Start the Rails server from `examples/rails_8_1/` with `bin/rails server`
- Start background job processing with `bin/jobs`
- Open `/job_workflow` for the monitoring UI and `/jobs` for Mission Control Jobs in the example app
- For a denser monitoring DAG preview, enqueue `AcceptanceComplexMonitoringDagJob` from `examples/rails_8_1/`

## Useful notes

- The example app is the main place to verify real monitoring UI behavior.
- The example app has its own lockfile and validation commands; treat it as an additional maintained surface.
- Use `examples/rails_8_1/README.md` for the full preview sequence.
- Use `guides/GETTING_STARTED.md` for first-time library setup and `guides/MONITORING_UI.md` for monitoring behavior.

## Unconfirmed items

- Preferred Ruby version manager for maintainers
- Any editor or shell configuration the team expects
