# frozen_string_literal: true

require_relative "monitoring/workflow_registry"
require_relative "monitoring/workflow_definition"
require_relative "monitoring/execution_page"
require_relative "monitoring/dag_layout"
require_relative "monitoring/parameter_filter"
require_relative "monitoring/execution_view_model"
require_relative "monitoring/execution_registry"

module JobWorkflow
  module Monitoring
    # @rbs!
    #   def self.base_controller_class: () -> untyped

    mattr_accessor :base_controller_class

    class << self
      #:  () -> Array[WorkflowDefinition]
      def workflows
        WorkflowRegistry.all.map { |job_class| WorkflowDefinition.new(job_class:) }
      end

      #:  (String?, ?status: Symbol?) -> String?
      def mission_control_job_path(job_id, status: nil)
        return if job_id.nil?

        path_template = mission_control_job_route_path
        return if path_template.nil?

        path = path_template.sub(":id", job_id.to_s)
        path += "#error" if status == :failed
        path
      end

      #:  () -> String
      def resolved_base_controller_class
        return base_controller_class if base_controller_class.present?

        mission_control_base_controller_class = defined?(MissionControl::Jobs) &&
                                                MissionControl::Jobs.base_controller_class
        return mission_control_base_controller_class if mission_control_base_controller_class.present?

        "::ApplicationController"
      end

      #:  (untyped config) -> void
      def configure_engine_config(config)
        config.job_workflow = ActiveSupport::OrderedOptions.new unless config.try(:job_workflow)
        config.job_workflow.monitoring ||= ActiveSupport::OrderedOptions.new

        config.before_initialize do
          config.job_workflow.monitoring.each do |key, value|
            JobWorkflow::Monitoring.public_send("#{key}=", value)
          end
        end
      end

      private

      #:  () -> String?
      def mission_control_job_route_path
        application_id = mission_control_application_id
        route_name = application_id ? "application_job" : "job"
        mount_path = mission_control_mount_path
        return if mount_path.nil?

        path = engine_route_path(route_name)
        return if path.nil?

        combined_path = "#{mount_path.chomp("/")}#{path}"
        application_id ? combined_path.sub(":application_id", application_id.to_s) : combined_path
      end

      #:  () -> String?
      def mission_control_application_id
        return unless defined?(MissionControl::Jobs)

        MissionControl::Jobs.applications.first&.id
      end

      #:  () -> String?
      def mission_control_mount_path
        path = rails_routes&.find { |candidate| candidate.name == "mission_control_jobs" }&.path
        normalized_route_path(path)
      end

      #:  (String) -> String?
      def engine_route_path(route_name)
        path = mission_control_routes&.find { |candidate| candidate.name == route_name }&.path
        normalized_route_path(path)
      end

      #:  (untyped) -> String?
      def normalized_route_path(path)
        return unless path.respond_to?(:spec)

        path_spec = path.spec.to_s
        return unless path_spec.is_a?(String) && !path_spec.empty?

        path_spec.delete_suffix("(.:format)")
      end

      #:  () -> untyped
      def mission_control_routes
        return unless defined?(MissionControl::Jobs::Engine)

        MissionControl::Jobs::Engine.routes.routes
      end

      #:  () -> untyped
      def rails_routes
        return unless defined?(Rails.application)
        return unless Rails.application.respond_to?(:routes)

        routes = Rails.application.routes
        return unless routes.respond_to?(:routes)

        routes.routes
      end
    end
  end
end
