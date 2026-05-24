# frozen_string_literal: true

RSpec.describe AcceptanceComplexMonitoringDagJob do
  let(:workflow_job) { described_class.new(services:, base_version:) }
  let(:workflow) { described_class._workflow }
  let(:services) { %w[api web worker] }
  let(:base_version) { 10 }

  describe "release plan tasks" do
    context "when preparing the release plan" do
      subject(:prepared_plan) { task(:prepare_release_plan).block.call(argument_context) }

      it "captures the services and base version" do
        expect(prepared_plan).to eq(service_names: services, base_version:)
      end
    end

    context "when building service artifacts" do
      subject(:artifact_versions) do
        context = context_with_plan
        context._with_each_value(task(:build_service_artifacts)).map do |task_context|
          task(:build_service_artifacts).block.call(task_context)[:artifact_version]
        end
      end

      it "derives artifact versions per service" do
        expect(artifact_versions).to eq([13, 13, 16])
      end
    end

    context "when running service verification" do
      subject(:verification_statuses) do
        context = context_with_plan
        context._with_each_value(task(:run_service_verification)).map do |task_context|
          task(:run_service_verification).block.call(task_context)[:check_status]
        end
      end

      it "produces one verification status per service" do
        expect(verification_statuses).to eq(%w[api_verified web_verified worker_verified])
      end
    end

    context "when summarizing artifact versions" do
      subject(:artifact_summary) { task(:summarize_artifact_versions).block.call(context_with_artifacts) }

      it "reports the latest version and count" do
        expect(artifact_summary).to eq(latest_version: 16, artifact_count: 3)
      end
    end

    context "when summarizing verification results" do
      subject(:verification_summary) { task(:summarize_verification_results).block.call(context_with_verifications) }

      it "reports the approved services" do
        expect(verification_summary).to eq(approved_count: 3, services: "api, web, worker")
      end
    end

    context "when composing the release overview" do
      subject(:release_overview) { task(:compose_release_overview).block.call(context_with_summaries) }

      it "builds the final headline from both summaries" do
        expect(release_overview).to eq(headline: "3 services ready at v16")
      end
    end

    context "when publishing the release summary" do
      subject(:published_summary) { task(:publish_release_summary).block.call(context_with_overview) }

      it "wraps the overview headline in the final message" do
        expect(published_summary).to eq(message: "release summary: 3 services ready at v16")
      end
    end
  end

  def task(name)
    workflow.fetch_task(name)
  end

  def argument_context
    JobWorkflow::Context.from_hash(job: workflow_job, workflow:)._update_arguments(services:, base_version:)
  end

  def context_with_plan
    context = argument_context
    append_output(context, :prepare_release_plan, task(:prepare_release_plan).block.call(context))
    context
  end

  def context_with_artifacts
    context = context_with_plan

    append_output(context, :build_service_artifacts, { service: "api", artifact_version: 13 })
    append_output(context, :build_service_artifacts, { service: "web", artifact_version: 13 }, each_index: 1)
    append_output(context, :build_service_artifacts, { service: "worker", artifact_version: 16 }, each_index: 2)
    context
  end

  def context_with_verifications
    context = context_with_plan

    append_output(context, :run_service_verification, { service: "api", check_status: "api_verified" })
    append_output(context, :run_service_verification, { service: "web", check_status: "web_verified" }, each_index: 1)
    append_output(
      context,
      :run_service_verification,
      { service: "worker", check_status: "worker_verified" },
      each_index: 2
    )
    context
  end

  def context_with_summaries
    context = context_with_plan

    append_output(context, :summarize_artifact_versions, { latest_version: 16, artifact_count: 3 })
    append_output(context, :summarize_verification_results, { approved_count: 3, services: "api, web, worker" })
    context
  end

  def context_with_overview
    context = context_with_summaries
    append_output(context, :compose_release_overview, { headline: "3 services ready at v16" })
    context
  end

  def append_output(context, task_name, data, each_index: 0)
    context._add_task_output(JobWorkflow::TaskOutput.new(task_name:, each_index:, data:))
  end
end
