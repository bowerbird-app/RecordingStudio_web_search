# frozen_string_literal: true

RecordingStudio.configure do |config|
  config.recordable_types = [ "Workspace", "Folder", "Page", "AdminRoot" ]
  config.recordable_types += [ "RecordingStudioApi::AdminApi" ]

  config.require_recordable_declarations = true

  config.app_name = "Web Search" if config.respond_to?(:app_name=)

  config.actor = -> { Current.actor }

  # Recording Studio 6.5+ fails closed unless a write authorizer is set.
  # Same Accessible path as the X dummy: grant/bootstrap writes go through
  # AccessCreationContext. Other writes need :edit on the root.
  # Token issue records the API client as actor, so the actor check is a
  # persisted recordable, not User-only. AccessCreationContext must not open
  # Folder/Page writes during grant-creation.
  config.authorize_write = lambda { |actor:, root_recording:, recordable:, **|
    next false unless defined?(RecordingStudioAccessible)
    next false unless actor.is_a?(ActiveRecord::Base) && actor.persisted?
    next false unless root_recording

    if defined?(RecordingStudio::Access) && recordable.is_a?(RecordingStudio::Access)
      next true if RecordingStudioAccessible::AccessCreationContext.allowed?

      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: root_recording,
        role: :admin
      )
    else
      RecordingStudioAccessible.authorized?(
        actor: actor,
        recording: root_recording,
        role: :edit
      )
    end
  }

  config.event_notifications_enabled = true

  config.idempotency_mode = :return_existing

  config.recordable_dup_strategy = :dup
end
