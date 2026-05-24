# frozen_string_literal: true

RSpec.describe JobWorkflow do
  let(:repo_root) { File.expand_path("..", __dir__) }

  it "has a version number" do
    expect(JobWorkflow::VERSION).not_to be_nil
  end

  describe "Rails integration loading" do
    let(:railtie_config) do
      Class.new do
        def after_initialize
          yield
        end
      end.new
    end

    let(:mock_railtie) do
      config = railtie_config
      Class.new do
        define_singleton_method(:config) { config }
      end
    end

    before { stub_const("Rails::Railtie", mock_railtie) }

    it "loads the railtie require path when Rails::Railtie is defined" do
      expect { load File.expand_path("../lib/job_workflow.rb", __dir__) }.not_to raise_error
    end
  end

  it "loads the Railtie when Rails::Railtie is defined" do
    expect { load_job_workflow_with_railtie_defined }.not_to raise_error
  end

  it "loads without requiring the Railtie when Rails::Railtie is not defined" do
    stub_const("Rails", Module.new)
    expect { load File.expand_path("../lib/job_workflow.rb", __dir__) }.not_to raise_error
  end

  describe "SolidQueue adapter initialization" do
    let(:mock_configuration) { Class.new }
    let(:mock_claimed_execution) { Class.new }

    before do
      stub_const("SolidQueue::Configuration", mock_configuration)
      stub_const("SolidQueue::ClaimedExecution", mock_claimed_execution)
      JobWorkflow::QueueAdapter.reset!
      JobWorkflow::QueueAdapter.current.initialize_adapter!
    end

    it "applies SchedulingPatch to SolidQueue::Configuration" do
      expect(mock_configuration.ancestors)
        .to include(JobWorkflow::QueueAdapters::SolidQueueAdapter::SchedulingPatch)
    end

    it "applies ClaimedExecutionPatch to SolidQueue::ClaimedExecution" do
      expect(mock_claimed_execution.ancestors)
        .to include(JobWorkflow::QueueAdapters::SolidQueueAdapter::ClaimedExecutionPatch)
    end
  end

  def build_fake_engine
    repo_root = self.repo_root

    Class.new do
      define_singleton_method(:isolate_namespace) { |*| nil }
      define_singleton_method(:root) { Pathname.new(repo_root) }
      define_singleton_method(:initializer) do |_, &block|
        block.call
      end
    end
  end

  def build_fake_railtie
    fake_config = Class.new do
      def after_initialize
        yield
      end
    end.new

    Class.new do
      define_singleton_method(:config) { fake_config }
    end
  end

  def load_job_workflow_with_railtie_defined
    stub_const("ActionController::Base", Class.new)
    stub_const("Rails", Module.new)
    stub_const("Rails::Engine", build_fake_engine)
    stub_const("Rails::Railtie", build_fake_railtie)
    hide_const("JobWorkflow::Monitoring::Engine") if JobWorkflow::Monitoring.const_defined?(:Engine, false)
    load File.expand_path("../lib/job_workflow.rb", __dir__)
  end
end
