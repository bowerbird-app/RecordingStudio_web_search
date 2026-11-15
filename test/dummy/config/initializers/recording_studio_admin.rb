# frozen_string_literal: true

Rails.application.config.to_prepare do
  admin_controller = RecordingStudioAdmin::ApplicationController
  next unless admin_controller.respond_to?(:skip_recording_studio_root_resolution)

  admin_controller.skip_recording_studio_root_resolution
end

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.layout = "recording_studio/default_layout"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  # Admin is its own root. A selected workspace must not block these pages.
  config.current_root_recording_resolver = ->(_context) { nil }

  config.access_recording_resolver = lambda do |context|
    RecordingStudioAccessible.admin_root(context: context) ||
      begin
        admin_root = AdminRoot.find_or_create_by!(name: "Admin")
        RecordingStudio.create_root_recording!(admin_root, actor: Current.actor)
      end
  end

  config.surface(:admin) do |surface|
    surface.root_section :web_search
    surface.layout = "recording_studio/default_layout"
  end
end
