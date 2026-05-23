# frozen_string_literal: true

module JobWorkflow
  class TaskEnqueue
    attr_reader :condition #: true | false | ^(Context) -> bool
    attr_reader :queue #: String?

    class << self
      #:  (true | false | ^(Context) -> bool | Hash[Symbol, untyped] | nil) -> TaskEnqueue
      def from_primitive_value(value)
        case value
        when TrueClass, FalseClass, Proc
          new(condition: value)
        when Hash
          validate_hash_keys!(value)

          new(
            condition: value.fetch(:condition, !value.empty?),
            queue: value[:queue]
          )
        else
          new
        end
      end

      private

      #: (Hash[Symbol, untyped]) -> void
      def validate_hash_keys!(value)
        unsupported_keys = value.keys - %i[condition queue]
        return if unsupported_keys.empty?

        if unsupported_keys == %i[concurrency]
          raise ArgumentError, "enqueue does not support :concurrency; use throttle instead"
        end

        raise ArgumentError, "enqueue supports only :condition and :queue"
      end
    end

    #:  (
    #     ?condition: true | false | ^(Context) -> bool,
    #     ?queue: String?
    #   ) -> void
    def initialize(condition: false, queue: nil)
      @condition = condition
      @queue = queue
    end

    #:  (Context) -> bool
    def should_enqueue?(context)
      return condition.call(context) if condition.is_a?(Proc)

      !!condition
    end
  end
end
