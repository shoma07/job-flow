# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    # :nocov:
    if defined?(Rails::Engine)
      class Engine < ::Rails::Engine
        isolate_namespace JobWorkflow::Monitoring

        JobWorkflow::Monitoring.configure_engine_config(config) if respond_to?(:config)
      end
    end
    # :nocov:
  end
end
