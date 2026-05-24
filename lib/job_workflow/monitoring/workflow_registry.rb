# frozen_string_literal: true

module JobWorkflow
  module Monitoring
    class WorkflowRegistry
      class << self
        #:  () -> Array[singleton(DSL)]
        def all
          DSL._included_classes.to_a
             .reverse
             .select(&:name)
             .uniq(&:name)
             .reverse
             .sort_by(&:name)
        end

        #:  (String) -> singleton(DSL)?
        def find(job_class_name)
          all.find { |job_class| job_class.name == job_class_name }
        end
      end
    end
  end
end
