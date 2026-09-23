# frozen_string_literal: true

class Admin::BaseController < ApplicationController
  include RecordingStudioAdmin::AdminActionAuditing

  # Admin is its own root. A selected workspace must not block these pages.
  skip_recording_studio_root_resolution

  layout "recording_studio/default_layout"

  before_action :authenticate_admin_user!
  before_action :authorize_admin_user!

  helper_method :recording_studio_admin_context, :recording_studio_admin_access_recording, :page_nav_anchor_url,
                :preserve_anchor_url, :admin_section_href

  private

  def authenticate_admin_user!
    method_name = RecordingStudioAdmin.configuration.authentication_method
    return send(method_name) if method_name && respond_to?(method_name, true)

    head :unauthorized
  end

  def authorize_admin_user!
    return if performed?

    RecordingStudioAdmin::Authorization.authorize!(
      recording_studio_admin_context,
      recording: recording_studio_admin_access_recording
    )
  rescue RecordingStudioAdmin::AuthorizationFailed
    head :forbidden
  end

  def recording_studio_admin_context
    @recording_studio_admin_context ||= RecordingStudioAdmin::Context.new(
      params: params.to_unsafe_h,
      current_actor: recording_studio_admin_current_actor,
      controller: self,
      routes: self,
      view_context: view_context
    )
  end

  def recording_studio_admin_current_actor
    method_name = RecordingStudioAdmin.configuration.current_actor_method
    send(method_name) if method_name && respond_to?(method_name, true)
  end

  def recording_studio_admin_access_recording
    @recording_studio_admin_access_recording ||= begin
      admin_root = AdminRoot.find_or_create_by!(name: "Admin")
      RecordingStudio.root_recording_for(admin_root)
    end
  end

  def admin_section_href(url)
    join_query(url, "anchor_url" => admin_root_path)
  end

  def page_nav_anchor_url(default: RecordingStudioAdmin.configuration.default_mount_path)
    safe_url = RecordingStudioAdmin::UrlSafety.safe_href(params[:anchor_url], allow_external: true)
    return default if safe_url.blank? || safe_url == "#"

    safe_url
  end

  def preserve_anchor_url(url)
    safe_url = RecordingStudioAdmin::UrlSafety.safe_href(url)
    anchor_url = page_nav_anchor_url

    return safe_url if safe_url.blank? || anchor_url.blank? || anchor_url == "#"
    return safe_url unless safe_url.start_with?("/")

    join_query(safe_url, "anchor_url" => anchor_url)
  rescue URI::InvalidURIError
    safe_url
  end

  def join_query(url, extra)
    uri = URI.parse(url.to_s)
    query = Rack::Utils.parse_nested_query(uri.query).merge(extra)
    uri.query = query.to_query.presence
    uri.to_s
  end
end
