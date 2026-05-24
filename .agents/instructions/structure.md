# Structure

## Repository layout

```text
.
├── app/                     # Rails engine assets for the monitoring UI
├── bin/                     # executable helpers
├── config/                  # Rails engine and routing configuration
├── examples/rails_8_1/      # acceptance Rails application used to verify integration
├── guides/                  # user-facing documentation
├── lib/                     # main JobWorkflow library code
├── sig/                     # generated signatures and type artifacts
├── sig-private/             # private type definitions used by Steep
├── spec/                    # main RSpec suite
├── .agents/instructions/    # agent instructions files referenced from AGENTS.md
└── AGENTS.md                # root agent entry point
```

## Key areas

- `lib/job_workflow/` holds the core DSL, runtime, adapters, monitoring models, and version file.
- `lib/job_workflow/monitoring/` contains monitoring presenters, registries, and layout helpers.
- `app/` and `config/routes.rb` support the monitoring UI engine.
- `examples/rails_8_1/` is a separate validation surface with its own Rake tasks, lockfile, and specs.
- `examples/rails_8_1/app/jobs/` contains acceptance workflow definitions.
- `examples/rails_8_1/spec/jobs/` contains acceptance and integration-oriented example-app specs.
- `guides/` is the documentation index for feature and operational guides.

## Structure expectations

- Treat this repository as a single package with an embedded example application, not as a monorepo of independent packages.
- Keep agent-wide documentation at the root unless a future task explicitly introduces subdirectory-specific AGENTS.md files.

## Documentation entry points

- Start with `guides/README.md` to find the right feature guide.
- Use `guides/MONITORING_UI.md` for monitoring-specific behavior.
- Use `examples/rails_8_1/README.md` for example-app setup and preview flows.

## Unconfirmed items

- Whether additional future example applications should get their own AGENTS.md
