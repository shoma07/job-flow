# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class WorkflowDefinition
      attr_reader :job_class #: singleton(DSL)

      #:  (job_class: singleton(DSL)) -> void
      def initialize(job_class:)
        @job_class = job_class
      end

      #:  () -> String
      def job_class_name
        job_class.name
      end

      #:  () -> Integer
      def task_count
        job_class._workflow.tasks.size
      end
    end
  end
end
