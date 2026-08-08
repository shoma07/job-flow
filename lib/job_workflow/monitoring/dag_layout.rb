# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class DagLayout
      # @rbs @nodes: Array[Hash[Symbol, untyped]]
      # @rbs @edges: Array[Hash[Symbol, untyped]]
      # @rbs @node_positions: Hash[Symbol, Hash[Symbol, Integer]]

      NODE_WIDTH = 224
      NODE_HEIGHT = 84
      COLUMN_GAP = 56
      ROW_GAP = 24
      PADDING = 16
      LABEL_LIMIT = 24

      #:  (tasks: Array[Hash[Symbol, untyped]]) -> void
      def initialize(tasks:)
        validate_tasks!(tasks)
        @tasks = tasks
      end

      #:  () -> Hash[Symbol, untyped]
      def to_h
        {
          width: canvas_width,
          height: canvas_height,
          nodes:,
          edges:
        }
      end

      private

      attr_reader :tasks #: Array[Hash[Symbol, untyped]]

      #:  (Array[Hash[Symbol, untyped]]) -> void
      def validate_tasks!(tasks)
        seen_names = {} #: Hash[Symbol, bool]

        tasks.each do |task|
          validate_dependencies!(task, seen_names)
          seen_names[task.fetch(:name)] = true
        end
      end

      #:  (Hash[Symbol, untyped], Hash[Symbol, bool]) -> void
      def validate_dependencies!(task, seen_names)
        missing_dependencies = task.fetch(:depends_on).reject { |dependency_name| seen_names[dependency_name] }
        return if missing_dependencies.empty?

        task_name = task.fetch(:name)
        dependency_names = missing_dependencies.join(", ")

        raise(
          ArgumentError,
          "DagLayout tasks must be topologically sorted; " \
          "#{task_name} depends on unavailable prior tasks: #{dependency_names}"
        )
      end

      #:  () -> Array[Hash[Symbol, untyped]]
      def nodes
        @nodes ||= tasks.map do |task|
          position = node_positions.fetch(task.fetch(:name))
          task.merge(
            x: x_for(position.fetch(:column)),
            y: y_for(position.fetch(:row)),
            width: NODE_WIDTH,
            height: NODE_HEIGHT,
            label: task.fetch(:name).to_s,
            truncated_label: truncate_label(task.fetch(:name)),
            meta_label: node_meta_label(task)
          )
        end
      end

      #:  () -> Array[Hash[Symbol, untyped]]
      def edges
        @edges ||= tasks.flat_map do |task|
          task.fetch(:depends_on).map do |dependency_name|
            edge_view(dependency_name, task.fetch(:name))
          end
        end
      end

      #:  () -> Hash[Symbol, Hash[Symbol, Integer]]
      def node_positions
        @node_positions ||= begin
          column_rows = Hash.new(0) #: Hash[Integer, Integer]
          positions = {} #: Hash[Symbol, Hash[Symbol, Integer]]

          tasks.each_with_object(positions) do |task, current_positions|
            column = dependency_column(task, current_positions)
            row = column_rows[column]
            column_rows[column] += 1
            current_positions[task.fetch(:name)] = { column:, row: }
          end
        end
      end

      #:  (Hash[Symbol, untyped], Hash[Symbol, Hash[Symbol, Integer]]) -> Integer
      def dependency_column(task, positions)
        depends_on = task.fetch(:depends_on)
        return 0 if depends_on.empty?

        depends_on.map { |dependency_name| positions.fetch(dependency_name).fetch(:column) + 1 }.max || 0
      end

      #:  (Symbol, Symbol) -> Hash[Symbol, untyped]
      def edge_view(from_name, to_name)
        from_node = node_view(from_name)
        to_node = node_view(to_name)
        {
          from: from_name,
          to: to_name,
          path: edge_path(from_node, to_node)
        }
      end

      #:  (Hash[Symbol, untyped], Hash[Symbol, untyped]) -> String
      def edge_path(from_node, to_node)
        start_x = from_node.fetch(:x) + from_node.fetch(:width)
        start_y = from_node.fetch(:y) + (from_node.fetch(:height) / 2)
        end_x = to_node.fetch(:x)
        end_y = to_node.fetch(:y) + (to_node.fetch(:height) / 2)
        mid_x = ((start_x + end_x) / 2.0).round(2)

        "M #{start_x} #{start_y} L #{mid_x} #{start_y} L #{mid_x} #{end_y} L #{end_x} #{end_y}"
      end

      #:  (Symbol) -> Hash[Symbol, untyped]
      def node_view(task_name)
        nodes.find { |task| task.fetch(:name) == task_name } || raise(KeyError, task_name.to_s)
      end

      #:  () -> Integer
      def canvas_width
        return 0 if nodes.empty?

        max_column = node_positions.values.map { |position| position.fetch(:column) }.max || 0
        (PADDING * 2) + ((max_column + 1) * NODE_WIDTH) + (max_column * COLUMN_GAP)
      end

      #:  () -> Integer
      def canvas_height
        return 0 if nodes.empty?

        max_row = node_positions.values.map { |position| position.fetch(:row) }.max || 0
        (PADDING * 2) + ((max_row + 1) * NODE_HEIGHT) + (max_row * ROW_GAP)
      end

      #:  (Integer) -> Integer
      def x_for(column)
        PADDING + (column * (NODE_WIDTH + COLUMN_GAP))
      end

      #:  (Integer) -> Integer
      def y_for(row)
        PADDING + (row * (NODE_HEIGHT + ROW_GAP))
      end

      #:  (Symbol) -> String
      def truncate_label(task_name)
        label = task_name.to_s
        return label if label.length <= LABEL_LIMIT

        "#{label[0, LABEL_LIMIT - 1]}…"
      end

      #:  (Hash[Symbol, untyped]) -> String?
      def node_meta_label(task)
        return root_task_label if task.fetch(:depends_on).empty?
        return each_progress_label(task.fetch(:each_progress)) if task.fetch(:each)

        nil
      end

      #:  () -> String
      def root_task_label
        "root task"
      end

      #:  (Hash[Symbol, Integer]) -> String
      def each_progress_label(progress)
        "each #{progress.fetch(:succeeded)}/#{progress.fetch(:total)}"
      end
    end
  end
end
