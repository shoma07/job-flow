# frozen_string_literal: true

# Job for acceptance testing - denser monitoring DAG example.
class AcceptanceComplexMonitoringDagJob < ApplicationJob
  include JobWorkflow::DSL

  argument :services, "Array[String]"
  argument :base_version, "Integer"

  task :prepare_release_plan,
       output: { service_names: "Array[String]", base_version: "Integer" } do |ctx|
    {
      service_names: ctx.arguments.services,
      base_version: ctx.arguments.base_version
    }
  end

  task :build_service_artifacts,
       depends_on: [:prepare_release_plan],
       each: ->(ctx) { ctx.output[:prepare_release_plan].first.service_names },
       enqueue: true,
       output: { service: "String", artifact_version: "Integer" } do |ctx|
    base_version = ctx.output[:prepare_release_plan].first.base_version
    service_name = ctx.each_value

    {
      service: service_name,
      artifact_version: base_version + service_name.length
    }
  end

  task :run_service_verification,
       depends_on: [:prepare_release_plan],
       each: ->(ctx) { ctx.output[:prepare_release_plan].first.service_names },
       enqueue: true,
       output: { service: "String", check_status: "String" } do |ctx|
    {
      service: ctx.each_value,
      check_status: "#{ctx.each_value}_verified"
    }
  end

  task :summarize_artifact_versions,
       depends_on: [:build_service_artifacts],
       dependency_wait: 30,
       output: { latest_version: "Integer", artifact_count: "Integer" } do |ctx|
    artifacts = ctx.output[:build_service_artifacts]
    {
      latest_version: artifacts.map(&:artifact_version).max || 0,
      artifact_count: artifacts.size
    }
  end

  task :summarize_verification_results,
       depends_on: [:run_service_verification],
       dependency_wait: 30,
       output: { approved_count: "Integer", services: "String" } do |ctx|
    verifications = ctx.output[:run_service_verification]
    {
      approved_count: verifications.size,
      services: verifications.map(&:service).join(", ")
    }
  end

  task :compose_release_overview,
       depends_on: %i[summarize_artifact_versions summarize_verification_results],
       output: { headline: "String" } do |ctx|
    artifact_summary = ctx.output[:summarize_artifact_versions].first
    verification_summary = ctx.output[:summarize_verification_results].first

    {
      headline: "#{verification_summary.approved_count} services ready at v#{artifact_summary.latest_version}"
    }
  end

  task :publish_release_summary,
       depends_on: [:compose_release_overview],
       output: { message: "String" } do |ctx|
    {
      message: "release summary: #{ctx.output[:compose_release_overview].first.headline}"
    }
  end
end
