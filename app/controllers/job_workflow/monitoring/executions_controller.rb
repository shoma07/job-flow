# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class ExecutionsController < ApplicationController
      def index
        @workflow = WorkflowRegistry.find(params[:workflow_job_class_name])
        return render plain: "Workflow definition not found.", status: :not_found if @workflow.nil?

        @page = ExecutionRegistry.page_for(
          job_class_name: @workflow.name,
          cursor: params[:cursor]
        )
        @executions = @page.executions
      end

      def show
        @workflow = WorkflowRegistry.find(params[:workflow_job_class_name])
        return render plain: "Workflow definition not found.", status: :not_found if @workflow.nil?

        @execution = ExecutionRegistry.find(params[:id])
        return if @execution && @execution.job_class_name == @workflow.name

        render plain: "Workflow execution is no longer available.", status: :not_found
      end
    end
  end
end
