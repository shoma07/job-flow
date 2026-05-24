# frozen_string_literal: true

Rails.application.routes.draw do
  mount MissionControl::Jobs::Engine => "/jobs"
  mount JobWorkflow::Monitoring::Engine => "/job_workflow"

  get "up" => "rails/health#show", as: :rails_health_check
end
