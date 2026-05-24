# frozen_string_literal: true

require_relative "../../support/monitoring_controller_loader"

RSpec.describe "JobWorkflow::Monitoring::WorkflowsController",
               monitoring_controller_consts: [:WorkflowsController],
               monitoring_controller_filename: "workflows_controller" do
  subject(:controller_class) { JobWorkflow::Monitoring::WorkflowsController }

  include_context "with isolated monitoring controller"

  it "assigns the registered workflows" do
    controller = controller_class.new
    workflows = [instance_double(JobWorkflow::Monitoring::WorkflowDefinition)]
    allow(JobWorkflow::Monitoring).to receive(:workflows).and_return(workflows)

    controller.index

    expect(controller.instance_variable_get(:@workflows)).to eq(workflows)
  end
end
