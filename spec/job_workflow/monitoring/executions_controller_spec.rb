# frozen_string_literal: true

require_relative "../../support/monitoring_controller_loader"

RSpec.describe "JobWorkflow::Monitoring::ExecutionsController",
               monitoring_controller_consts: [:ExecutionsController],
               monitoring_controller_filename: "executions_controller" do
  subject(:controller_class) { JobWorkflow::Monitoring::ExecutionsController }

  include_context "with isolated monitoring controller"

  let(:controller) { controller_class.new }

  describe "#index" do
    let(:workflow) { instance_double(Class, name: "KnownWorkflow") }
    let(:page) { instance_double(JobWorkflow::Monitoring::ExecutionPage, executions: [:execution]) }

    context "when workflow definition is missing" do
      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: "MissingWorkflow" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(nil)
        allow(controller).to receive(:render)
        controller.index
      end

      it "renders not found" do
        expect(controller).to have_received(:render).with(
          plain: "Workflow definition not found.", status: :not_found
        )
      end
    end

    context "when workflow exists" do
      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: workflow.name, cursor: "cursor-1" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(workflow)
        allow(JobWorkflow::Monitoring::ExecutionRegistry).to receive(:page_for).and_return(page)
        controller.index
      end

      it("assigns the workflow") { expect(controller.instance_variable_get(:@workflow)).to eq(workflow) }
      it("assigns the page") { expect(controller.instance_variable_get(:@page)).to eq(page) }
      it("assigns the executions") { expect(controller.instance_variable_get(:@executions)).to eq([:execution]) }
    end
  end

  describe "#show" do
    let(:workflow) { instance_double(Class, name: "KnownWorkflow") }
    let(:job_class_name) { "KnownWorkflow" }
    let(:execution) { instance_double(JobWorkflow::Monitoring::ExecutionViewModel, job_class_name:) }
    let(:execution_record) { execution }

    context "when workflow definition is missing" do
      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: "MissingWorkflow", id: "1" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(nil)
        allow(controller).to receive(:render)
        controller.show
      end

      it "renders not found" do
        expect(controller).to have_received(:render).with(
          plain: "Workflow definition not found.", status: :not_found
        )
      end
    end

    context "when execution matches the workflow" do
      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: workflow.name, id: "job-1" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(workflow)
        allow(JobWorkflow::Monitoring::ExecutionRegistry).to receive(:find).and_return(execution_record)
        allow(controller).to receive(:render)
        controller.show
      end

      it("assigns the workflow") { expect(controller.instance_variable_get(:@workflow)).to eq(workflow) }
      it("assigns the execution") { expect(controller.instance_variable_get(:@execution)).to eq(execution) }
      it("does not render not found") { expect(controller).not_to have_received(:render) }
    end

    context "when execution is missing" do
      let(:execution_record) { nil }

      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: workflow.name, id: "job-1" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(workflow)
        allow(JobWorkflow::Monitoring::ExecutionRegistry).to receive(:find).and_return(execution_record)
        allow(controller).to receive(:render)
        controller.show
      end

      it "renders not found" do
        expect(controller).to have_received(:render).with(
          plain: "Workflow execution is no longer available.", status: :not_found
        )
      end
    end

    context "when execution belongs to another workflow" do
      let(:job_class_name) { "OtherWorkflow" }

      before do
        allow(controller).to receive(:params).and_return({ workflow_job_class_name: workflow.name, id: "job-1" })
        allow(JobWorkflow::Monitoring::WorkflowRegistry).to receive(:find).and_return(workflow)
        allow(JobWorkflow::Monitoring::ExecutionRegistry).to receive(:find).and_return(execution_record)
        allow(controller).to receive(:render)
        controller.show
      end

      it "renders not found" do
        expect(controller).to have_received(:render).with(
          plain: "Workflow execution is no longer available.", status: :not_found
        )
      end
    end
  end
end
