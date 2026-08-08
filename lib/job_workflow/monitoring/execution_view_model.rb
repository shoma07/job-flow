# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class ExecutionViewModel
      # @rbs @tasks: Array[Hash[Symbol, untyped]]
      # @rbs @failed_task_name: Symbol?
      # @rbs @dag_layout: Hash[Symbol, untyped]

      attr_reader :job_id #: String
      attr_reader :queue_name #: String?
      attr_reader :status #: WorkflowStatus

      #:  (job_id: String, queue_name: String?, status: WorkflowStatus) -> void
      def initialize(job_id:, queue_name:, status:)
        @job_id = job_id
        @queue_name = queue_name
        @status = status
      end

      #:  () -> String
      def job_class_name
        status.job_class_name
      end

      #:  () -> Symbol
      def workflow_status
        status.status
      end

      #:  () -> Symbol?
      def current_task_name
        status.current_task_name
      end

      #:  () -> Arguments
      def arguments
        status.arguments
      end

      #:  () -> Hash[untyped, untyped]
      def filtered_arguments
        ParameterFilter.filter(arguments.to_h)
      end

      #:  () -> Array[Hash[Symbol, untyped]]
      def tasks
        @tasks ||= status.context.workflow.tasks.map { |task| task_view_model(task) }
      end

      #:  () -> Symbol?
      def failed_task_name
        @failed_task_name ||= begin
          failed_task = tasks.find { |task| task[:status] == :failed }
          failed_task&.fetch(:name)
        end
      end

      #:  () -> String?
      def mission_control_job_path
        JobWorkflow::Monitoring.mission_control_job_path(job_id, status: workflow_status)
      end

      #:  () -> Hash[Symbol, untyped]
      def dag_layout
        @dag_layout ||= DagLayout.new(tasks:).to_h
      end

      #:  () -> bool
      def running?
        workflow_status == :running
      end

      #:  () -> Hash[Symbol, untyped]
      def to_h
        {
          job_id:,
          queue_name:,
          job_class_name:,
          status: workflow_status,
          current_task_name:,
          failed_task_name:,
          arguments: filtered_arguments,
          tasks:,
          mission_control_job_path:
        }
      end

      private

      #:  (Symbol, Array[TaskOutput], Array[TaskJobStatus]) -> Symbol
      def task_status(task_name, task_outputs, task_job_statuses)
        return :failed if task_job_statuses.any?(&:failed?)
        return :succeeded if completed_task?(task_name, task_outputs, task_job_statuses)
        return :running if task_running?(task_name, task_job_statuses)

        :pending
      end

      #:  (Symbol, Array[TaskOutput], Array[TaskJobStatus]) -> bool
      def completed_task?(task_name, task_outputs, task_job_statuses)
        return true if !running? && task_outputs.any?
        return task_job_statuses.all?(&:succeeded?) if task_job_statuses.any?
        return true if status.completed_task_names.include?(task_name)

        task_outputs.any?
      end

      #:  (Symbol, Array[TaskJobStatus]) -> bool
      def task_running?(task_name, task_job_statuses)
        current_task_running?(task_name) ||
          (!task_job_statuses.empty? && task_job_statuses.any? { |task_status| !task_status.finished? })
      end

      #:  (Symbol) -> bool
      def current_task_running?(task_name) = running? && current_task_name == task_name

      #:  (Task) -> Hash[Symbol, untyped]
      def task_view_model(task)
        task_name = task.task_name
        task_outputs, task_job_statuses = task_state(task_name)

        task_configuration_view(task).merge(
          task_runtime_view(task_name, task_outputs, task_job_statuses)
        )
      end

      #:  (Task) -> Hash[Symbol, untyped]
      def task_configuration_view(task)
        {
          name: task.task_name,
          depends_on: task.depends_on,
          each: task.each?,
          configuration: task_configuration(task)
        }
      end

      #:  (Symbol, Array[TaskOutput], Array[TaskJobStatus]) -> Hash[Symbol, untyped]
      def task_runtime_view(task_name, task_outputs, task_job_statuses)
        {
          status: task_status(task_name, task_outputs, task_job_statuses),
          each_progress: each_progress(task_outputs, task_job_statuses),
          outputs: task_outputs_view(task_outputs),
          sub_task_jobs: sub_task_jobs_view(task_job_statuses)
        }
      end

      #:  (Symbol) -> [Array[TaskOutput], Array[TaskJobStatus]]
      def task_state(task_name) = [status.output.fetch_all(task_name:), status.job_status.fetch_all(task_name:)]

      #:  (Task) -> Hash[Symbol, untyped]
      def task_configuration(task)
        {
          job_name: task.job_name,
          each: callable_summary(task.each),
          condition: callable_summary(task.condition),
          enqueue: enqueue_configuration(task),
          outputs: output_configuration(task),
          retry: retry_configuration(task),
          throttle: throttle_configuration(task),
          timeout: task.timeout,
          dependency_wait: dependency_wait_configuration(task),
          dry_run: callable_summary(task.dry_run_config.evaluator)
        }
      end

      #:  (Task) -> Hash[Symbol, untyped]
      def enqueue_configuration(task)
        {
          enabled: primitive_summary(task.enqueue.condition),
          queue: task.enqueue.queue
        }
      end

      #:  (Task) -> Array[Hash[Symbol, untyped]]
      def output_configuration(task)
        task.output.map { |output| { name: output.name, type: output.type } }
      end

      #:  (Task) -> Hash[Symbol, untyped]
      def retry_configuration(task)
        {
          count: task.task_retry.count,
          strategy: task.task_retry.strategy,
          base_delay: task.task_retry.base_delay,
          jitter: task.task_retry.jitter
        }
      end

      #:  (Task) -> Hash[Symbol, untyped]
      def throttle_configuration(task)
        {
          key: task.throttle.key,
          limit: task.throttle.limit,
          ttl: task.throttle.ttl
        }
      end

      #:  (Task) -> Hash[Symbol, untyped]
      def dependency_wait_configuration(task)
        {
          poll_timeout: task.dependency_wait.poll_timeout,
          poll_interval: task.dependency_wait.poll_interval,
          reschedule_delay: task.dependency_wait.reschedule_delay,
          polling_only: task.dependency_wait.polling_only?
        }
      end

      #:  (untyped) -> untyped
      def callable_summary(value)
        case value
        when nil
          nil
        when Proc
          "proc"
        else
          value
        end
      end

      #:  (untyped) -> untyped
      def primitive_summary(value)
        value.is_a?(Proc) ? "proc" : value
      end

      #:  (Array[TaskOutput], Array[TaskJobStatus]) -> Hash[Symbol, Integer]
      def each_progress(task_outputs, task_job_statuses)
        {
          total: [task_outputs.size, task_job_statuses.size].max,
          succeeded: task_job_statuses.count { |task_job_status| task_job_status.succeeded? }, # rubocop:disable Style/SymbolProc
          failed: task_job_statuses.count { |task_job_status| task_job_status.failed? }, # rubocop:disable Style/SymbolProc
          pending: task_job_statuses.count { |task_status| task_status.status == :pending },
          running: task_job_statuses.count { |task_status| task_status.status == :running }
        }
      end

      #:  (Array[TaskOutput]) -> Array[Hash[Symbol, untyped]]
      def task_outputs_view(task_outputs)
        task_outputs.map do |output|
          { each_index: output.each_index, data: ParameterFilter.filter(output.data) }
        end
      end

      #:  (Array[TaskJobStatus]) -> Array[Hash[Symbol, untyped]]
      def sub_task_jobs_view(task_job_statuses)
        Array(task_job_statuses).map do |task_job_status|
          {
            job_id: task_job_status.job_id,
            each_index: task_job_status.each_index,
            status: task_job_status.status,
            mission_control_job_path: mission_control_job_path_for(task_job_status.job_id, task_job_status.status)
          }
        end
      end

      #:  (String?, Symbol?) -> String?
      def mission_control_job_path_for(job_id, status = nil)
        JobWorkflow::Monitoring.mission_control_job_path(job_id, status:)
      end
    end
  end
end
