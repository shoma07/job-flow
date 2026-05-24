# frozen_string_literal: true

RSpec.describe JobWorkflow::Monitoring do
  let(:adapter) { JobWorkflow::QueueAdapters::NullAdapter.new }
  let(:workflow_class) do
    Class.new(ActiveJob::Base) do
      include JobWorkflow::DSL

      def self.name = "MonitoringWorkflowJob"

      argument :user_id, "Integer", default: 7

      task :prepare, output: { payload: "String" } do |_ctx|
        { payload: "ready" }
      end

      task :fan_out,
           each: ->(_ctx) { [1, 2] },
           depends_on: [:prepare],
           enqueue: { queue: "critical" },
           retry: { count: 3, strategy: :exponential, base_delay: 2, jitter: true },
           throttle: { key: "fan-out", limit: 5, ttl: 60 },
           timeout: 30,
           dependency_wait: { poll_timeout: 15, poll_interval: 2, reschedule_delay: 9 },
           dry_run: true do |_ctx|
        # work
      end
    end
  end

  let(:other_workflow_class) do
    Class.new(ActiveJob::Base) do
      include JobWorkflow::DSL

      def self.name = "OtherMonitoringWorkflowJob"

      task :only_task, output: { payload: "String" } do |_ctx|
        { payload: "other" }
      end
    end
  end

  before do
    stub_const("MonitoringWorkflowJob", workflow_class)
    stub_const("OtherMonitoringWorkflowJob", other_workflow_class)
    allow(JobWorkflow::QueueAdapter).to receive(:current).and_return(adapter)
    stub_const("Rails", Class.new) unless defined?(Rails)
    allow(Rails).to receive(:application).and_return(
      double(config: double(filter_parameters: [:token, :api_key, /secret/i]))
    )
  end

  after do
    JobWorkflow::DSL._included_classes.delete(workflow_class)
    JobWorkflow::DSL._included_classes.delete(other_workflow_class)
  end

  describe ".workflows" do
    subject(:workflow) do
      described_class.workflows.find { |definition| definition.job_class_name == "MonitoringWorkflowJob" }
    end

    it { is_expected.to have_attributes(task_count: 2) }
  end

  describe ".resolved_base_controller_class" do
    after { described_class.base_controller_class = nil }

    it "prefers JobWorkflow monitoring configuration" do
      described_class.base_controller_class = "AdminController"
      stub_const("MissionControl::Jobs", Class.new do
        def self.base_controller_class = "MissionControlController"
      end)

      expect(described_class.resolved_base_controller_class).to eq("AdminController")
    end

    it "falls back to mission control jobs when available" do
      stub_const("MissionControl::Jobs", Class.new do
        def self.base_controller_class = "MissionControlController"
      end)

      expect(described_class.resolved_base_controller_class).to eq("MissionControlController")
    end

    it "defaults to ApplicationController when no override is present" do
      hide_const("MissionControl::Jobs") if defined?(MissionControl::Jobs)
      expect(described_class.resolved_base_controller_class).to eq("::ApplicationController")
    end

    it "falls back to ApplicationController when mission control has no override" do
      stub_const("MissionControl::Jobs", Class.new do
        def self.base_controller_class = nil
      end)

      expect(described_class.resolved_base_controller_class).to eq("::ApplicationController")
    end
  end

  describe ".mission_control_job_path" do
    it "returns nil without a job id" do
      expect(described_class.mission_control_job_path(nil)).to be_nil
    end

    it "returns nil when mission control jobs is not mounted" do
      remove_mission_control_jobs
      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when mission control jobs is available without a show route" do
      stub_mission_control_jobs
      stub_mission_control_routes([])
      stub_mission_control_mount("/jobs(.:format)")

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when mission control is mounted but engine routes are unavailable" do
      stub_mission_control_jobs
      hide_const("MissionControl::Jobs::Engine")
      stub_mission_control_mount("/jobs(.:format)")

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when the mission control route path is not inspectable" do
      stub_mission_control_jobs
      stub_mission_control_mount("/jobs(.:format)")
      stub_mission_control_routes([double(name: "job", path: double)])

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when the mission control route path does not stringify to a non-empty String" do
      stub_mission_control_jobs
      stub_mission_control_mount("/jobs(.:format)")
      stub_mission_control_routes([double(name: "job", path: double(spec: double(to_s: nil)))])

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when Rails routes cannot enumerate mounted routes" do
      stub_mission_control_jobs
      stub_const("Rails", Class.new) unless defined?(Rails)
      allow(Rails).to receive(:application).and_return(double(routes: double))

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when Rails.application does not expose routes" do
      stub_mission_control_jobs
      stub_const("Rails", Class.new) unless defined?(Rails)
      allow(Rails).to receive(:application).and_return(double)

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "returns nil when Rails is unavailable" do
      stub_mission_control_jobs
      hide_const("Rails")

      expect(described_class.mission_control_job_path("job-1")).to be_nil
    end

    it "builds a route using the host application's show route" do
      stub_mission_control_jobs
      stub_mission_control_mount("/jobs(.:format)")
      stub_mission_control_routes([route_double(name: "job", path: "/jobs/:id(.:format)")])

      expect(described_class.mission_control_job_path("job-1")).to eq("/jobs/jobs/job-1")
    end

    it "uses the application-scoped route when mission control has an application id" do
      stub_mission_control_jobs(application_id: "example")
      stub_mission_control_mount("/jobs(.:format)")
      application_routes = [
        route_double(name: "application_job", path: "/applications/:application_id/jobs/:id(.:format)")
      ]
      stub_mission_control_routes(application_routes)

      expect(described_class.mission_control_job_path("job-1")).to eq("/jobs/applications/example/jobs/job-1")
    end

    it "adds the error anchor for failed jobs" do
      stub_mission_control_jobs
      stub_mission_control_mount("/jobs(.:format)")
      stub_mission_control_routes([route_double(name: "job", path: "/jobs/:id(.:format)")])

      expect(described_class.mission_control_job_path("job-1", status: :failed)).to eq("/jobs/jobs/job-1#error")
    end
  end

  describe ".configure_engine_config" do
    after { described_class.base_controller_class = nil }

    it "initializes monitoring config and applies overrides during before_initialize" do
      config = build_monitoring_config
      expect(configure_monitoring_config(config, base_controller_class: "AdminController")).to eq(
        [ActiveSupport::OrderedOptions, "AdminController"]
      )
    end

    it "reuses an existing job_workflow config object" do
      config = build_monitoring_config
      config.job_workflow = ActiveSupport::OrderedOptions.new.tap { |options| options[:existing] = true }

      described_class.configure_engine_config(config)

      expect(config.job_workflow[:existing]).to be(true)
    end

    it "preserves an existing monitoring config object" do
      config = build_monitoring_config
      existing_monitoring_config = ActiveSupport::OrderedOptions.new.tap { |options| options[:existing] = true }
      config.job_workflow = ActiveSupport::OrderedOptions.new.tap { |options| options.monitoring = existing_monitoring_config }

      described_class.configure_engine_config(config)

      expect(config.job_workflow.monitoring[:existing]).to be(true)
    end
  end

  describe "engine loading" do
    let(:engine_path) { File.expand_path("../../lib/job_workflow/monitoring/engine.rb", __dir__) }

    it "configures the engine when the superclass exposes config" do
      fake_config = build_engine_config
      stub_engine_superclass(fake_config)
      hide_const("JobWorkflow::Monitoring::Engine") if described_class.const_defined?(:Engine, false)
      load engine_path
      expect(described_class::Engine.config.job_workflow.monitoring).to be_a(ActiveSupport::OrderedOptions)
    end
  end

  describe JobWorkflow::Monitoring::WorkflowRegistry do
    it { expect(described_class.find("MonitoringWorkflowJob")).to eq(workflow_class) }
    it { expect(described_class.find("UnknownWorkflowJob")).to be_nil }

    it "deduplicates workflows with the same class name" do
      duplicate_workflow = build_duplicate_workflow_class
      stub_const("DuplicateMonitoringWorkflowJob", duplicate_workflow)
      expect(described_class.all.count { |job_class| job_class.name == "MonitoringWorkflowJob" }).to eq(1)
      JobWorkflow::DSL._included_classes.delete(duplicate_workflow)
    end

    it "prefers the latest workflow definition for duplicate class names" do
      duplicate_workflow = build_duplicate_workflow_class(with_task: true)
      stub_const("UpdatedMonitoringWorkflowJob", duplicate_workflow)
      expect(described_class.find("MonitoringWorkflowJob")).to eq(duplicate_workflow)
      JobWorkflow::DSL._included_classes.delete(duplicate_workflow)
    end
  end

  describe JobWorkflow::Monitoring::ExecutionRegistry do
    describe ".page_for" do
      before do
        adapter.store_job("root-1", root_job_data(job_id: "root-1", status: :running))
        adapter.store_job("child-1", sub_task_job_record(job_id: "child-1", parent_job_id: "root-1"))
        adapter.store_job("root-2", root_job_data(job_id: "root-2", status: :pending))
        adapter.store_job("other-root", other_root_job_data(job_id: "other-root"))
      end

      let(:first_page) { described_class.page_for(job_class_name: "MonitoringWorkflowJob", limit: 1) }

      it "returns only root executions for the requested workflow" do
        expect(first_page.executions.map(&:job_id)).to eq(["root-2"])
      end

      it { expect(first_page.next_cursor).to eq("1") }

      it "uses the cursor for the next root page" do
        page = described_class.page_for(job_class_name: "MonitoringWorkflowJob", limit: 1, cursor: "1")
        expect(page.executions.map(&:job_id)).to eq(["root-1"])
      end
    end

    describe ".find" do
      it "returns nil for unavailable executions" do
        expect(described_class.find("missing")).to be_nil
      end

      it "returns nil for SubTaskJob rows" do
        adapter.store_job("child-1", sub_task_job_record(job_id: "child-1", parent_job_id: "root-1"))
        expect(described_class.find("child-1")).to be_nil
      end

      it "hydrates sub task outputs and statuses for details" do
        stub_sub_task_state

        fan_out_task = described_class.find("root-1").tasks.find { |task| task[:name] == :fan_out }

        expect(fan_out_task).to include(
          status: :running,
          each_progress: hash_including(total: 2, succeeded: 1, running: 1),
          outputs: include(hash_including(each_index: 0, data: { "result" => "child" })),
          sub_task_jobs: contain_exactly(
            hash_including(
              job_id: "child-1",
              each_index: 0,
              status: :succeeded,
              mission_control_job_path: nil
            ),
            hash_including(
              job_id: "child-2",
              each_index: 1,
              status: :running,
              mission_control_job_path: nil
            )
          )
        )
      end

      it "drops executions whose workflow class cannot be resolved" do
        unknown_job = { "job_id" => "unknown", "class_name" => "UnknownWorkflowJob", "status" => :pending }
        expect(described_class.send(:build_view_model, unknown_job)).to be_nil
      end

      it "does not swallow unexpected NoMethodError" do
        allow(JobWorkflow::WorkflowStatus).to receive(:from_job_data).and_raise(NoMethodError, "boom")

        expect do
          described_class.send(:build_view_model, root_job_data(job_id: "root-1", status: :pending))
        end.to raise_error(NoMethodError, "boom")
      end
    end
  end

  describe JobWorkflow::Monitoring::ExecutionViewModel do
    let(:failed_execution) do
      status = JobWorkflow::WorkflowStatus.from_job_data(failed_root_job_data)
      described_class.new(job_id: "job-2", queue_name: nil, status:)
    end

    it { expect(failed_execution.failed_task_name).to eq(:fan_out) }
    it { expect(failed_execution.tasks).to include(hash_including(name: :prepare, status: :pending)) }
    it { expect(failed_execution.running?).to be(false) }

    it "returns nil when no task has failed" do
      expect(running_execution.failed_task_name).to be_nil
    end

    it "memoizes tasks" do
      allow(failed_execution).to receive(:task_view_model).and_call_original

      failed_execution.tasks
      failed_execution.tasks

      expect(failed_execution).to have_received(:task_view_model).twice
    end

    it "memoizes failed_task_name" do
      allow(failed_execution.tasks).to receive(:find).and_call_original

      failed_execution.failed_task_name
      failed_execution.failed_task_name

      expect(failed_execution.tasks).to have_received(:find).once
    end

    it "marks the current task succeeded when the workflow has already finished and produced output" do
      status = JobWorkflow::WorkflowStatus.from_job_data(succeeded_root_job_data)
      execution = described_class.new(job_id: "job-1", queue_name: nil, status:)

      expect(execution.tasks).to include(hash_including(name: :fan_out, status: :succeeded))
    end

    it "marks the current task running while the workflow is active" do
      status = JobWorkflow::WorkflowStatus.from_job_data(running_root_job_data)
      execution = described_class.new(job_id: "job-1", queue_name: nil, status:)

      expect(execution.tasks).to include(hash_including(name: :fan_out, status: :running))
    end

    it "keeps fan-out running when unfinished child jobs remain after the current task advances" do
      data = root_job_data(job_id: "job-3", status: :running)
      data.fetch("job_workflow_context").fetch("task_context")["task_name"] = "prepare"
      status = JobWorkflow::WorkflowStatus.from_job_data(data)
      execution = described_class.new(job_id: "job-3", queue_name: nil, status:)

      expect(execution.tasks).to include(hash_including(name: :fan_out, status: :running))
    end

    it do
      expect(failed_execution.to_h).to include(
        job_id: "job-2", job_class_name: "MonitoringWorkflowJob", status: :failed, current_task_name: nil
      )
    end

    it "filters sensitive values in arguments" do
      execution = described_class.new(job_id: "job-3", queue_name: nil, status: filtered_arguments_status)
      expect(execution.filtered_arguments).to eq(
        "user_id" => 7, "token" => "[FILTERED]", "api_key" => "[FILTERED]"
      )
    end

    it "filters sensitive values in task outputs" do
      prepare_task = described_class.new(
        job_id: "job-1", queue_name: nil, status: JobWorkflow::WorkflowStatus.from_job_data(filtered_output_job_data)
      ).tasks.find { |task| task[:name] == :prepare }
      expect(prepare_task[:outputs]).to include(
        hash_including(
          data: { "token" => "[FILTERED]", "nested_secret" => "[FILTERED]", "safe" => "ok" }
        )
      )
    end

    it "includes task configuration in the DAG view model" do
      fan_out_task = running_execution.tasks.find { |task| task[:name] == :fan_out }

      expect(fan_out_task[:configuration]).to include(
        job_name: "MonitoringWorkflowJob",
        each: "proc",
        condition: "proc",
        enqueue: {
          enabled: true,
          queue: "critical"
        },
        retry: {
          count: 3,
          strategy: :exponential,
          base_delay: 2,
          jitter: true
        },
        throttle: {
          key: "fan-out",
          limit: 5,
          ttl: 60
        },
        timeout: 30,
        dependency_wait: {
          poll_timeout: 15,
          poll_interval: 2,
          reschedule_delay: 9,
          polling_only: false
        },
        dry_run: "proc"
      )
    end

    it "exposes sub task job link data for task detail rendering" do
      fan_out_task = failed_execution.tasks.find { |task| task[:name] == :fan_out }

      expect(fan_out_task[:sub_task_jobs]).to contain_exactly(
        hash_including(
          job_id: "child-3",
          each_index: 0,
          status: :failed,
          mission_control_job_path: nil
        )
      )
    end

    it "returns an empty sub task job list when task job statuses are unavailable" do
      expect(running_execution.send(:sub_task_jobs_view, nil)).to eq([])
    end

    it { expect(running_execution.send(:callable_summary, nil)).to be_nil }
    it { expect(running_execution.send(:callable_summary, :symbolic)).to eq(:symbolic) }
    it { expect(running_execution.send(:primitive_summary, ->(_ctx) { true })).to eq("proc") }
    it { expect(running_execution.send(:mission_control_job_path_for, nil)).to be_nil }

    it "delegates mission control link generation to monitoring" do
      allow(JobWorkflow::Monitoring).to receive(:mission_control_job_path)
        .with("job-1", status: :running)
        .and_return("/mc/jobs/job-1")

      expect(running_execution.mission_control_job_path).to eq("/mc/jobs/job-1")
    end

    it "omits a Mission Control path without a job id" do
      status = JobWorkflow::WorkflowStatus.from_job_data(root_job_data(job_id: "job-1", status: :pending))
      execution = described_class.new(job_id: nil, queue_name: nil, status:)
      expect(execution.mission_control_job_path).to be_nil
    end
  end

  describe JobWorkflow::Monitoring::ParameterFilter do
    it "filters nested hashes and arrays with Rails filter_parameters" do
      value = {
        "token" => "secret-token",
        "safe" => "ok",
        "nested" => { "api_key" => "secret-key" },
        "items" => [{ "secret_value" => "hidden" }]
      }

      expect(described_class.filter(value)).to eq(
        "token" => "[FILTERED]",
        "safe" => "ok",
        "nested" => { "api_key" => "[FILTERED]" },
        "items" => [{ "secret_value" => "[FILTERED]" }]
      )
    end

    it "filters arrays recursively and leaves scalar values unchanged" do
      expect(described_class.filter([{ "token" => "secret-token" }, "safe"])).to eq(
        [{ "token" => "[FILTERED]" }, "safe"]
      )
    end

    it "returns values unchanged when Rails.application is unavailable" do
      hide_const("Rails")
      expect(described_class.filter("token" => "secret-token")).to eq("token" => "secret-token")
    end
  end

  def filtered_arguments_status
    instance_double(
      JobWorkflow::WorkflowStatus,
      arguments: instance_double(
        JobWorkflow::Arguments,
        to_h: { "user_id" => 7, "token" => "secret-token", "api_key" => "secret-key" }
      )
    )
  end

  def running_execution
    status = JobWorkflow::WorkflowStatus.from_job_data(running_root_job_data)
    JobWorkflow::Monitoring::ExecutionViewModel.new(job_id: "job-1", queue_name: nil, status:)
  end

  def build_monitoring_config
    Class.new do
      attr_accessor :job_workflow

      def initialize = @before_initialize_blocks = []
      def before_initialize(&block) = @before_initialize_blocks << block
      def run_before_initialize = @before_initialize_blocks.each(&:call)
    end.new
  end

  def build_engine_config
    Class.new do
      attr_accessor :job_workflow

      def before_initialize(&block) = @before_initialize_block = block
    end.new
  end

  def remove_mission_control_jobs
    hide_const("MissionControl::Jobs") if defined?(MissionControl::Jobs)
  end

  def stub_mission_control_jobs(application_id: nil)
    application = application_id && double(id: application_id)
    applications = application ? [application] : []
    stub_const("MissionControl::Jobs", Class.new do
      define_singleton_method(:applications) { applications }
    end)
    stub_const("MissionControl::Jobs::Engine", Class.new)
  end

  def route_double(name:, path:)
    double(name:, path: double(spec: double(to_s: path)))
  end

  def stub_mission_control_mount(path)
    stub_mission_control_host_routes([route_double(name: "mission_control_jobs", path:)])
  end

  def stub_mission_control_routes(routes)
    engine_routes = double(routes:)
    allow(MissionControl::Jobs::Engine).to receive(:routes).and_return(engine_routes)
  end

  def stub_mission_control_host_routes(routes)
    stub_const("Rails", Class.new) unless defined?(Rails)
    allow(Rails).to receive(:application).and_return(double(routes: double(routes:)))
  end

  def build_duplicate_workflow_class(with_task: false)
    Class.new(ActiveJob::Base) do
      include JobWorkflow::DSL

      def self.name = "MonitoringWorkflowJob"

      if with_task
        task :updated_task do |_ctx|
          { payload: "updated" }
        end
      end
    end
  end

  def configure_monitoring_config(config, base_controller_class:)
    described_class.configure_engine_config(config)
    config.job_workflow.monitoring.base_controller_class = base_controller_class
    config.run_before_initialize
    [config.job_workflow.monitoring.class, described_class.base_controller_class]
  end

  def stub_engine_superclass(fake_config)
    stub_const("Rails::Engine", Class.new do
      define_singleton_method(:config) { fake_config }
      define_singleton_method(:isolate_namespace) { |_namespace| nil }
    end)
  end

  def stub_sub_task_state
    adapter.store_job("root-1", root_job_data(job_id: "root-1", status: :running))
    adapter.store_job("child-1", sub_task_job_record(job_id: "child-1", parent_job_id: "root-1"))
    stub_running_sub_task_status
    stub_sub_task_contexts
  end

  def stub_running_sub_task_status
    allow(adapter).to receive(:fetch_job_statuses).with(["child-2"]).and_return(
      "child-2" => instance_double(Object)
    )
    allow(adapter).to receive(:job_status).and_return(:running)
  end

  def stub_sub_task_contexts
    allow(adapter).to receive(:fetch_job_contexts).with(%w[child-1 child-2]).and_return(
      [sub_task_job_context(parent_job_id: "root-1", each_index: 0, result: "child")]
    )
  end

  def root_job_data(job_id:, status:)
    {
      "job_id" => job_id,
      "class_name" => "MonitoringWorkflowJob",
      "queue_name" => "default",
      "status" => status,
      "job_workflow_context" => {
        "task_context" => {
          "task_name" => "fan_out",
          "parent_job_id" => nil,
          "index" => 1,
          "value" => nil,
          "retry_count" => 0
        },
        "task_outputs" => [
          { "task_name" => "prepare", "each_index" => 0, "data" => { "payload" => "ready" } }
        ],
        "task_job_statuses" => [
          { "task_name" => "fan_out", "job_id" => "child-1", "each_index" => 0, "status" => "succeeded" },
          { "task_name" => "fan_out", "job_id" => "child-2", "each_index" => 1, "status" => "pending" }
        ]
      }
    }
  end

  def other_root_job_data(job_id:)
    {
      "job_id" => job_id,
      "class_name" => "OtherMonitoringWorkflowJob",
      "queue_name" => "default",
      "status" => :pending,
      "job_workflow_context" => {
        "task_context" => {
          "task_name" => nil,
          "parent_job_id" => nil,
          "index" => 0,
          "value" => nil,
          "retry_count" => 0
        },
        "task_outputs" => [],
        "task_job_statuses" => []
      }
    }
  end

  def sub_task_job_record(job_id:, parent_job_id:)
    {
      "job_id" => job_id,
      "class_name" => JobWorkflow::SubTaskJob.name,
      "queue_name" => "critical",
      "status" => :succeeded,
      "job_workflow_context" => sub_task_job_context(parent_job_id:, each_index: 0, result: "child")
    }
  end

  def sub_task_job_context(parent_job_id:, each_index:, result:)
    {
      "task_context" => {
        "task_name" => "fan_out",
        "parent_job_id" => parent_job_id,
        "index" => each_index,
        "value" => each_index + 1,
        "retry_count" => 0
      },
      "task_outputs" => [
        { "task_name" => "fan_out", "each_index" => each_index, "data" => { "result" => result } }
      ],
      "task_job_statuses" => []
    }
  end

  def failed_root_job_data
    {
      "job_id" => "job-2",
      "class_name" => "MonitoringWorkflowJob",
      "queue_name" => "default",
      "status" => :failed,
      "job_workflow_context" => {
        "task_context" => {
          "task_name" => nil, "parent_job_id" => nil, "index" => 0, "value" => nil, "retry_count" => 0
        },
        "task_outputs" => [],
        "task_job_statuses" => [
          { "task_name" => "fan_out", "job_id" => "child-3", "each_index" => 0, "status" => "failed" }
        ]
      }
    }
  end

  def succeeded_root_job_data
    root_job_data(job_id: "job-1", status: :succeeded).tap do |data|
      data.fetch("job_workflow_context").fetch("task_outputs") << {
        "task_name" => "fan_out", "each_index" => 0, "data" => { "result" => "done" }
      }
    end
  end

  def filtered_output_job_data
    succeeded_root_job_data.tap do |data|
      data.fetch("job_workflow_context").fetch("task_outputs") << {
        "task_name" => "prepare",
        "each_index" => 1,
        "data" => { "token" => "secret-token", "nested_secret" => "secret-value", "safe" => "ok" }
      }
    end
  end

  def running_root_job_data
    root_job_data(job_id: "job-1", status: :running).tap do |data|
      data.fetch("job_workflow_context")["task_job_statuses"] = []
    end
  end
end
