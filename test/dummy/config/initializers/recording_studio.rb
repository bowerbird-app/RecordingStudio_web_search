# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [ "Workspace", "Folder", "Page", "AdminRoot" ]
  config.recordable_types += [ "RecordingStudioApi::AdminApi" ]

  config.require_recordable_declarations = true

  config.app_name = "Web Search" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  config.authorize_write = lambda { |actor:, action:, **|
    return false if action.to_s.strip.empty?

    actor.nil? || actor.is_a?(ActiveRecord::Base)
  }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
