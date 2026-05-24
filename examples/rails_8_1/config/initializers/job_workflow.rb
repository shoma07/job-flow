# frozen_string_literal: true

# SQLite does not support FOR UPDATE SKIP LOCKED, so we need to disable it for testing
# See: https://www.sqlite.org/lang_select.html#the_for_update_clause
module JobWorkflowInitializer
  class << self
    def configure_solid_queue
      SolidQueue.use_skip_locked = false if defined?(SolidQueue)
    end
  end
end

JobWorkflowInitializer.configure_solid_queue

# Load the sample workflow classes so the monitoring UI can show their definitions in development.
Rails.application.config.after_initialize do
  Rails.root.glob("app/jobs/*.rb").each { |path| require path }
end
