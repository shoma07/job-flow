# frozen_string_literal: true

RSpec.describe JobWorkflow::Monitoring::DagLayout do
  describe "#to_h" do
    subject(:layout) { described_class.new(tasks:).to_h }

    context "when tasks are present" do
      let(:tasks) do
        [
          task_view(name: :build, status: :succeeded, depends_on: []),
          task_view(
            name: :test_suite_for_pull_requests_and_release_candidates,
            status: :running,
            depends_on: [:build],
            each: true,
            each_progress: { total: 4, succeeded: 2, failed: 0, pending: 1, running: 1 }
          ),
          task_view(name: :lint, status: :succeeded, depends_on: [:build]),
          task_view(
            name: :deploy,
            status: :pending,
            depends_on: %i[test_suite_for_pull_requests_and_release_candidates lint]
          )
        ]
      end

      it do
        expect(layout).to include(
          width: 816,
          height: 224,
          nodes: include(
            hash_including(name: :build, x: 16, y: 16, truncated_label: "build", meta_label: "root task"),
            hash_including(
              name: :test_suite_for_pull_requests_and_release_candidates,
              x: 296,
              y: 16,
              truncated_label: "test_suite_for_pull_req…",
              meta_label: "each 2/4"
            ),
            hash_including(name: :lint, x: 296, y: 124, meta_label: nil),
            hash_including(name: :deploy, x: 576, y: 16, meta_label: nil)
          ),
          edges: contain_exactly(
            hash_including(from: :build, to: :test_suite_for_pull_requests_and_release_candidates),
            hash_including(from: :build, to: :lint),
            hash_including(from: :test_suite_for_pull_requests_and_release_candidates, to: :deploy),
            hash_including(from: :lint, to: :deploy)
          )
        )
      end
    end

    context "when tasks are empty" do
      let(:tasks) { [] }

      it { expect(layout).to eq(width: 0, height: 0, nodes: [], edges: []) }
    end

    context "when tasks are not topologically sorted" do
      let(:tasks) do
        [
          task_view(name: :deploy, status: :pending, depends_on: [:build]),
          task_view(name: :build, status: :succeeded, depends_on: [])
        ]
      end

      it "raises a clear argument error" do
        expect { layout }.to raise_error(
          ArgumentError,
          "DagLayout tasks must be topologically sorted; deploy depends on unavailable prior tasks: build"
        )
      end
    end
  end

  def task_view(name:, status:, depends_on:, each: false, each_progress: nil)
    {
      name:,
      status:,
      depends_on:,
      each:,
      each_progress: each_progress || { total: 0, succeeded: 0, failed: 0, pending: 0, running: 0 },
      configuration: {},
      outputs: [],
      sub_task_jobs: []
    }
  end
end
