# frozen_string_literal: true

Rails.application.config.to_prepare do
  admin_controller = RecordingStudioAdmin::ApplicationController
  next unless admin_controller.respond_to?(:skip_recording_studio_root_resolution)

  admin_controller.skip_recording_studio_root_resolution
end

RecordingStudioAdmin.configure do |config|
  config.default_mount_path = "/admin"
  config.engine_layout = "recording_studio/default_layout"
  config.authentication_method = :authenticate_user!
  config.current_actor_method = :current_user

  config.access_recording_resolver = lambda do |_context|
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    RecordingStudio.root_recording_for(admin_root)
  end
  config.site_admin_recording_resolver = config.access_recording_resolver

  config.surface(:admin) do |surface|
    surface.root_section :web_search
    surface.engine_layout = "recording_studio/default_layout"
  end
end
