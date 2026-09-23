# frozen_string_literal: true

# The default layout passes anchor_url. Page nav only draws the close control from anchor_href.
module AdminPageNavAnchor
  def initialize(*args, anchor_url: nil, **kwargs)
    kwargs[:anchor_href] = anchor_url if kwargs[:anchor_href].blank? && anchor_url.present?
    super(*args, **kwargs)
  end
end

Rails.application.config.to_prepare do
  page_nav = FlatPack::PageNav::Component
  page_nav.prepend(AdminPageNavAnchor) unless page_nav < AdminPageNavAnchor
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
