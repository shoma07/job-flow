# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class WorkflowsController < ApplicationController
      # @rbs @workflows: Array[WorkflowDefinition]

      #:  () -> void
      def index
        @workflows = Monitoring.workflows
      end
    end
  end
end
