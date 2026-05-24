# Monitoring UI

## Overview

JobWorkflow ships with a workflow-oriented monitoring UI. Instead of listing mixed job rows first, the UI starts
from workflow definitions, then lets you drill into one workflow's root executions and finally into one execution's
DAG state.

This view is intended to answer workflow-level questions such as:

- which workflow is currently stuck
- which task is running or failed
- how `each` fan-out is progressing
- which arguments and outputs shaped the current execution

## What the UI shows

The current scope includes:

- workflow definition list
- paginated root execution list per workflow
- execution detail with DAG, task state, arguments, outputs, and failed task
- fan-out progress and sub-task job links into Mission Control Jobs

History analytics, retries, and dry-run launch flows are out of scope for now.

## Navigation

The UI is organized around workflows rather than a cross-workflow execution feed:

```text
workflow definitions
  └─ one workflow's root executions
       └─ one root execution with sub-task-job detail
```

The UI is intentionally scoped to one workflow at a time, so the first screen stays focused on definitions and the
execution list stays easy to scan.

## Mounting the engine

Add the engine to your application's routes:

```ruby
# config/routes.rb
mount JobWorkflow::Monitoring::Engine => "/job_workflow"
```

After mounting, open `/job_workflow` to browse workflow definitions and executions.

## Authentication and controller inheritance

By default, monitoring controllers inherit from `ApplicationController`. If you already use a dedicated authenticated
controller for admin tooling, configure monitoring to inherit from it:

```ruby
config.job_workflow.monitoring.base_controller_class = "AdminController"
```

If `config.job_workflow.monitoring.base_controller_class` is not set and `MissionControl::Jobs` is installed,
monitoring falls back to `MissionControl::Jobs.base_controller_class`.

## Root executions and sub-task jobs

Execution lists show **root jobs only**. `SubTaskJob` rows do not appear in the workflow execution list. Instead, the
detail page shows sub-task job state only after you open one root execution.

This keeps the list view focused on workflow-level monitoring while still preserving the full fan-out story on the
detail page.

## Query behavior

Root executions are paginated with a cursor and scoped by workflow class. As a user, this means the execution list is
ordered newest-first within the workflow you selected, without mixing in unrelated job rows.
