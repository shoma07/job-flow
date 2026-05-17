# frozen_string_literal: true

require "spec_helper"

RSpec.describe JobWorkflow::TaskEnqueue do
  describe ".from_primitive_value" do
    subject(:task_enqueue) { described_class.from_primitive_value(value) }

    context "when value is true" do
      let(:value) { true }

      it do
        expect(task_enqueue).to have_attributes(
          condition: true,
          queue: nil
        )
      end
    end

    context "when value is false" do
      let(:value) { false }

      it do
        expect(task_enqueue).to have_attributes(
          condition: false,
          queue: nil
        )
      end
    end

    context "when value is a Proc" do
      let(:value) { ->(ctx) { ctx.arguments.enabled } }

      it do
        expect(task_enqueue).to have_attributes(
          condition: value,
          queue: nil
        )
      end
    end

    context "when value is a Hash with condition" do
      let(:value) { { condition: true } }

      it do
        expect(task_enqueue).to have_attributes(
          condition: true,
          queue: nil
        )
      end
    end

    context "when value is a Hash with condition: false" do
      let(:value) { { condition: false } }

      it do
        expect(task_enqueue).to have_attributes(
          condition: false,
          queue: nil
        )
      end
    end

    context "when value is a Hash with queue" do
      let(:value) { { queue: "high_priority" } }

      it do
        expect(task_enqueue).to have_attributes(
          condition: true,
          queue: "high_priority"
        )
      end
    end

    context "when value is a Hash with concurrency" do
      let(:value) { { concurrency: 5 } }

      it do
        expect { task_enqueue }.to raise_error(
          ArgumentError,
          "enqueue does not support :concurrency; use throttle instead"
        )
      end
    end

    context "when value is a Hash with unsupported key" do
      let(:value) { { queue: "high_priority", priority: 10 } }

      it { expect { task_enqueue }.to raise_error(ArgumentError, "enqueue supports only :condition and :queue") }
    end

    context "when value is an empty Hash" do
      let(:value) { {} }

      it do
        expect(task_enqueue).to have_attributes(
          condition: false,
          queue: nil
        )
      end
    end

    context "when value is nil" do
      let(:value) { nil }

      it do
        expect(task_enqueue).to have_attributes(
          condition: false,
          queue: nil
        )
      end
    end

    context "when value is an unexpected type" do
      let(:value) { :invalid_symbol }

      it do
        expect(task_enqueue).to have_attributes(
          condition: false,
          queue: nil
        )
      end
    end
  end

  describe "#should_enqueue?" do
    subject(:should_enqueue) { task_enqueue.should_enqueue?(context) }

    let(:context) { instance_double(JobWorkflow::Context) }

    context "when condition is true" do
      let(:task_enqueue) { described_class.new(condition: true) }

      it { is_expected.to be true }
    end

    context "when condition is false" do
      let(:task_enqueue) { described_class.new(condition: false) }

      it { is_expected.to be false }
    end

    context "when condition is a Proc returning true" do
      let(:task_enqueue) { described_class.new(condition: ->(_ctx) { true }) }

      it { is_expected.to be true }
    end

    context "when condition is a Proc returning false" do
      let(:task_enqueue) { described_class.new(condition: ->(_ctx) { false }) }

      it { is_expected.to be false }
    end
  end
end
