# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class ExecutionPage
      attr_reader :executions #: Array[ExecutionViewModel]
      attr_reader :next_cursor #: String?

      #:  (executions: Array[ExecutionViewModel], next_cursor: String?) -> void
      def initialize(executions:, next_cursor:)
        @executions = executions
        @next_cursor = next_cursor
      end
    end
  end
end
