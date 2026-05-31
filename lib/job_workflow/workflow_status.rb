# frozen_string_literal: true

module JobWorkflow
  class WorkflowStatus
    class NotFoundError < StandardError; end

    # @rbs!
    #   type status_type = :pending | :running | :completed | :failed

    attr_reader :context #: Context
    attr_reader :job_class_name #: String
    attr_reader :status #: status_type
    attr_reader :completed_task_names #: Array[Symbol]

    class << self
      #:  (String) -> WorkflowStatus
      def find(job_id)
        workflow_status = find_by(job_id:)
        raise NotFoundError, "Workflow with job_id '#{job_id}' not found" if workflow_status.nil?

        workflow_status
      end

      #:  (job_id: String) -> WorkflowStatus?
      def find_by(job_id:)
        data = QueueAdapter.current.find_job(job_id)
        return if data.nil?
        return if data["class_name"] == JobWorkflow::SubTaskJob.name

        WorkflowStatus.from_job_data(data)
      end

      #:  (Hash[String, untyped]) -> WorkflowStatus
      def from_job_data(data)
        job_class_name = data["class_name"]
        job_class = job_class_name.constantize
        workflow = job_class._workflow
        context = context_from_job_data(data, workflow)

        new(
          context:,
          job_class_name:,
          status: data["status"],
          completed_task_names: completed_task_names_from_job_data(data)
        )
      end

      private

      #:  (Hash[String, untyped]) -> Array[Symbol]
      def completed_task_names_from_job_data(data)
        Array(data.dig("continuation", "completed")).map(&:to_sym)
      end

      #:  (Hash[String, untyped], Workflow) -> Context
      def context_from_job_data(data, workflow)
        context_data = data["job_workflow_context"] || data["arguments"]&.first&.dig("job_workflow_context")
        context = if context_data
                    Context.deserialize(context_data.merge("workflow" => workflow))
                  else
                    Context.from_hash({ workflow: })
                  end
        serialized_arguments = workflow_arguments_data(data)
        return context if serialized_arguments.nil?

        context._update_arguments(ActiveJob::Arguments.deserialize([serialized_arguments]).first)
      end

      #:  (Hash[String, untyped]) -> Hash[String, untyped]?
      def workflow_arguments_data(data)
        serialized_arguments = data["arguments"]&.first
        return if serialized_arguments.nil? || serialized_arguments.key?("job_workflow_context")

        serialized_arguments
      end
    end

    #:  (
    #      context: Context,
    #      job_class_name: String,
    #      status: status_type,
    #      ?completed_task_names: Array[Symbol]
    #    ) -> void
    def initialize(context:, job_class_name:, status:, completed_task_names: [])
      @context = context #: Context
      @job_class_name = job_class_name #: String
      @status = status #: Symbol
      @completed_task_names = completed_task_names
    end

    #:  () -> Symbol?
    def current_task_name
      context._task_context.task&.task_name
    end

    #:  () -> Arguments
    def arguments
      context.arguments
    end

    #:  () -> Output
    def output
      context.output
    end

    #:  () -> JobStatus
    def job_status
      context.job_status
    end

    #:  () -> bool
    def running?
      status == :running
    end

    #:  () -> bool
    def completed?
      status == :succeeded
    end

    #:  () -> bool
    def failed?
      status == :failed
    end

    #:  () -> bool
    def pending?
      status == :pending
    end

    #:  () -> Hash[Symbol, untyped]
    def to_h
      {
        status:,
        job_class_name:,
        current_task_name:,
        arguments: arguments.to_h,
        output: output.flat_task_outputs.map do |task_output|
          {
            task_name: task_output.task_name,
            each_index: task_output.each_index,
            data: task_output.data
          }
        end
      }
    end
  end
end
