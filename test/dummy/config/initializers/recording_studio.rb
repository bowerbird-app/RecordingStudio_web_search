# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [ "Workspace", "Folder", "Page", "AdminRoot" ]
  config.recordable_types += [ "RecordingStudioApi::AdminApi" ] if defined?(RecordingStudioApi)

  config.require_recordable_declarations = true

  config.app_name = "Web Search" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  # Core 7 refuses writes until a host authorizer is set. A present actor may
  # create a root (root_recording is nil on that call) and may record children.
  config.authorize_write = lambda { |actor:, **|
    actor.present?
  }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
