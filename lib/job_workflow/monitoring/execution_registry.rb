# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class ExecutionRegistry
      DEFAULT_LIMIT = 25
      private_constant :DEFAULT_LIMIT

      class << self
        #:  (job_class_name: String, ?limit: Integer, ?cursor: String?) -> ExecutionPage
        def page_for(job_class_name:, limit: DEFAULT_LIMIT, cursor: nil)
          page = QueueAdapter.current.fetch_root_workflow_job_page(job_class_name:, limit:, cursor:)
          executions = page.fetch(:jobs).filter_map { |job_data| build_view_model(job_data) }
          ExecutionPage.new(executions:, next_cursor: page[:next_cursor])
        end

        #:  (String) -> ExecutionViewModel?
        def find(job_id)
          job_data = QueueAdapter.current.find_job(job_id)
          return if job_data.nil?

          build_view_model(job_data, hydrate_sub_tasks: true)
        end

        private

        #:  (Hash[String, untyped], ?hydrate_sub_tasks: bool) -> ExecutionViewModel?
        def build_view_model(job_data, hydrate_sub_tasks: false)
          return if job_data["class_name"] == JobWorkflow::SubTaskJob.name

          status = WorkflowStatus.from_job_data(job_data)
          hydrate_sub_task_state(status) if hydrate_sub_tasks
          ExecutionViewModel.new(job_id: job_data.fetch("job_id"), queue_name: job_data["queue_name"], status:)
        rescue NameError => e
          raise e if e.is_a?(NoMethodError)

          nil
        end

        #:  (WorkflowStatus) -> void
        def hydrate_sub_task_state(status)
          status.job_status.refresh_from_db!
          sub_task_job_ids = status.job_status.flat_task_job_statuses.map(&:job_id)
          sub_task_contexts = QueueAdapter.current.fetch_job_contexts(sub_task_job_ids)
          status.output.update_task_outputs_from_contexts(sub_task_contexts, status.context.workflow)
        end
      end
    end
  end
end
