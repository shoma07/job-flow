# frozen_string_literal: true

require "active_support/parameter_filter"

module JobWorkflow
  module Monitoring
    class ParameterFilter
      class << self
        #: (untyped) -> untyped
        def filter(value)
          case value
          when Hash
            parameter_filter.filter(value)
          when Array
            value.map { |item| filter(item) }
          else
            value
          end
        end

        private

        #: () -> ActiveSupport::ParameterFilter
        def parameter_filter
          ActiveSupport::ParameterFilter.new(filters)
        end

        #: () -> Array[untyped]
        def filters
          return [] unless defined?(Rails.application) && Rails.application.config.respond_to?(:filter_parameters)

          Rails.application.config.filter_parameters
        end
      end
    end
  end
end
