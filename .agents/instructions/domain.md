# Domain

## Repository purpose

JobWorkflow is a workflow orchestration library for Ruby on Rails applications. It provides a declarative DSL on top of ActiveJob so applications can define task graphs, dependencies, fan-out work, retries, throttling, and monitoring.

## Core concepts

- `Workflow`: the ordered graph of tasks for a job class
- `Task`: one unit of work in a workflow, optionally depending on other tasks
- `Arguments`: immutable workflow inputs exposed to tasks through `Context`
- `Context`: the task-facing object used to read arguments, outputs, runtime helpers, and execution state
- `Output`: the structured result store for completed task outputs
- `Runner`: the orchestration layer that executes tasks and updates workflow state
- `SubTaskJob`: the dedicated async job class used for `enqueue: true` fan-out work
- `WorkflowStatus` / `JobStatus`: read models for workflow and sub-task execution state
- Monitoring UI: the Rails engine that visualizes workflow definitions and execution DAGs

## Common terminology

- `each task`: a task that fans out over a collection
- `dependency_wait`: waiting behavior for dependent async work
- `fan-out`: splitting work into sub-jobs
- `root execution`: the top-level workflow job, excluding sub-task jobs

## Detailed references

- `guides/GETTING_STARTED.md` for the high-level workflow model
- `guides/DSL_BASICS.md` for task definitions and dependency rules
- `guides/TASK_OUTPUTS.md` for output flow and downstream consumption
- `guides/PARALLEL_PROCESSING.md` for fan-out and aggregation behavior
- `guides/WORKFLOW_STATUS_QUERY.md` for workflow vs job status read models
- `guides/MONITORING_UI.md` for the monitoring view of root executions and sub-task jobs

## Unconfirmed items

- Additional external domain vocabulary used by downstream adopters
