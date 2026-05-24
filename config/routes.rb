# frozen_string_literal: true

JobWorkflow::Monitoring::Engine.routes.draw do
  resources :workflows, only: [:index], param: :job_class_name do
    resources :executions, only: %i[index show]
  end
  root "workflows#index"
end
