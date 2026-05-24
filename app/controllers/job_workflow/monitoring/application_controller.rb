# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    # Resolve the host app controller at load time so engine controllers inherit
    # the app's existing authentication and access control hooks.
    class ApplicationController < JobWorkflow::Monitoring.resolved_base_controller_class.constantize
      layout "job_workflow/monitoring/application"
    end
  end
end
