# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class WorkflowsController < ApplicationController
      def index
        @workflows = Monitoring.workflows
      end
    end
  end
end
