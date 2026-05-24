# frozen_string_literal: true

module MonitoringControllerLoader
  module_function

  def load!(controller_filename:) # rubocop:disable Metrics/MethodLength
    state = {
      created_action_controller: false,
      created_action_controller_base: false,
      created_application_controller: false
    }

    unless Object.const_defined?(:ActionController, false)
      Object.const_set(:ActionController, Module.new)
      state[:created_action_controller] = true
    end

    unless ActionController.const_defined?(:Base, false)
      ActionController.const_set(:Base, Class.new do
        def self.layout(*) = nil
      end)
      state[:created_action_controller_base] = true
    end

    unless Object.const_defined?(:ApplicationController, false)
      Object.const_set(:ApplicationController, Class.new(ActionController::Base))
      state[:created_application_controller] = true
    end

    load(application_controller_path)
    load(controller_path(controller_filename))
    state
  end

  def unload!(state, controller_consts:) # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    Array(controller_consts).each { |const_name| unload_monitoring_const(const_name) }
    unload_monitoring_const(:ApplicationController)

    if state[:created_application_controller] && Object.const_defined?(:ApplicationController, false)
      Object.send(:remove_const, :ApplicationController) # rubocop:disable RSpec/RemoveConst
    end

    if state[:created_action_controller_base] &&
       Object.const_defined?(:ActionController, false) &&
       ActionController.const_defined?(:Base, false)
      ActionController.send(:remove_const, :Base) # rubocop:disable RSpec/RemoveConst
    end

    return unless state[:created_action_controller] && Object.const_defined?(:ActionController, false)

    Object.send(:remove_const, :ActionController) # rubocop:disable RSpec/RemoveConst
  end

  def application_controller_path
    File.expand_path("../../app/controllers/job_workflow/monitoring/application_controller.rb", __dir__)
  end

  def controller_path(controller_filename)
    File.expand_path("../../app/controllers/job_workflow/monitoring/#{controller_filename}.rb", __dir__)
  end

  def unload_monitoring_const(const_name)
    return unless defined?(JobWorkflow::Monitoring)
    return unless JobWorkflow::Monitoring.const_defined?(const_name, false)

    JobWorkflow::Monitoring.send(:remove_const, const_name) # rubocop:disable RSpec/RemoveConst
  end
end

# rubocop:disable RSpec/BeforeAfterAll, RSpec/InstanceVariable
RSpec.shared_context "with isolated monitoring controller" do
  before(:context) do
    metadata = self.class.metadata
    @monitoring_controller_loader_state = MonitoringControllerLoader.load!(
      controller_filename: metadata.fetch(:monitoring_controller_filename)
    )
  end

  after(:context) do
    metadata = self.class.metadata
    MonitoringControllerLoader.unload!(
      @monitoring_controller_loader_state,
      controller_consts: metadata.fetch(:monitoring_controller_consts)
    )
  end
end
# rubocop:enable RSpec/BeforeAfterAll, RSpec/InstanceVariable
