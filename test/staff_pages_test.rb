# frozen_string_literal: true

require "test_helper"

class StaffPagesTest < Minitest::Test
  def setup
    @web_search = RecordingStudio::WebSearch
    install_admin!
  end

  def teardown
    restore_support!
    restore_const(@web_search, :RunsController, @original_runs_controller, @had_runs_controller)
    remove_const(Object, :RecordingStudioAdmin)
  end

  def test_searches_return_keeps_a_safe_anchor
    assert_equal "/staff/screens/web_search_runs", RecordingStudio::WebSearch::SearchesReturn.path(nil)
    assert_equal "/staff/screens/web_search_runs", RecordingStudio::WebSearch::SearchesReturn.path("#")
    assert_equal "/staff/screens/web_search_runs", RecordingStudio::WebSearch::SearchesReturn.path("https://evil.test")
    assert_equal "/admin", RecordingStudio::WebSearch::SearchesReturn.anchor("", default: "/admin")

    path = RecordingStudio::WebSearch::SearchesReturn.path("/admin/root")
    assert_includes path, "/staff/screens/web_search_runs?"
    assert_includes path, "anchor_url="
    assert_equal "/admin/root", RecordingStudio::WebSearch::SearchesReturn.anchor("/admin/root", default: "/admin")
  end

  def test_searches_return_uses_admin_when_the_mount_is_blank
    RecordingStudioAdmin.configuration.default_mount_path = ""

    assert_equal "/admin/screens/web_search_runs", RecordingStudio::WebSearch::SearchesReturn.path(nil)
  end

  def test_run_page_prepares_root_switching_once
    support = Module.new
    controller = Class.new
    install_root_support!(support)
    install_runs_controller!(controller)

    RecordingStudio::WebSearch::RunPage.prepare!
    RecordingStudio::WebSearch::RunPage.prepare!

    assert_includes controller.ancestors, support
    assert_equal 1, controller.skip_calls
  end

  def test_staff_gate_signs_in_and_checks_access
    host = gate_host
    host.actor = :admin
    RecordingStudioAdmin.configuration.access_recording_resolver = ->(_context) { :root }

    host.authenticate_staff!
    host.authorize_staff!

    assert host.authenticated
    assert_empty host.statuses
    assert_equal "/admin/root", host.page_nav_anchor_url(default: "/admin")
  end

  def test_staff_gate_refuses_a_missing_sign_in_method
    host = gate_host
    RecordingStudioAdmin.configuration.authentication_method = :missing_sign_in

    host.authenticate_staff!

    assert_equal [:unauthorized], host.statuses
  end

  def test_staff_gate_stops_when_access_is_denied
    host = gate_host
    RecordingStudioAdmin.configuration.access_recording_resolver = ->(_context) {}

    host.authorize_staff!

    assert_equal [:forbidden], host.statuses
  end

  def test_staff_gate_does_not_authorize_twice
    host = gate_host
    host.performed = true

    host.authorize_staff!

    assert_empty host.statuses
  end

  def test_staff_gate_refuses_when_admin_is_missing
    remove_const(Object, :RecordingStudioAdmin)
    denied = gate_host
    denied.authorize_staff!
    assert_equal [:forbidden], denied.statuses

    unsigned = gate_host
    unsigned.authenticate_staff!
    assert_equal [:unauthorized], unsigned.statuses
  end

  private

  def install_admin!
    admin = Module.new
    admin.const_set(:AuthorizationFailed, Class.new(StandardError))
    admin.const_set(:Context, admin_context)
    admin.const_set(:Authorization, admin_authorization(admin))
    admin.const_set(:UrlSafety, admin_url_safety)
    config = Struct.new(
      :default_mount_path, :authentication_method, :current_actor_method, :access_recording_resolver
    ).new("/staff", :authenticate_user!, :current_user, nil)
    admin.define_singleton_method(:configuration) { config }
    Object.const_set(:RecordingStudioAdmin, admin)
  end

  def admin_context
    Class.new do
      attr_reader :current_actor

      def initialize(current_actor: nil, **_kwargs)
        @current_actor = current_actor
      end
    end
  end

  def admin_authorization(admin)
    authorization = Module.new
    authorization.define_singleton_method(:authorize!) do |context, recording:|
      raise admin::AuthorizationFailed unless recording && context.current_actor
    end
    authorization
  end

  def admin_url_safety
    safety = Module.new
    safety.define_singleton_method(:safe_href) do |value, allow_external:|
      text = value.to_s
      next if text.empty? || text == "#" || text.include?("://")

      text if allow_external || text.start_with?("/")
    end
    safety
  end

  def install_root_support!(support)
    @installed_root_switchable = !RecordingStudio.const_defined?(:RootSwitchable, false)
    parent = if @installed_root_switchable
               RecordingStudio.const_set(:RootSwitchable, Module.new)
             else
               RecordingStudio::RootSwitchable
             end
    @had_support = parent.const_defined?(:ControllerSupport, false)
    @original_support = parent.const_get(:ControllerSupport) if @had_support
    parent.send(:remove_const, :ControllerSupport) if @had_support
    parent.const_set(:ControllerSupport, support)
  end

  def install_runs_controller!(controller)
    controller.define_singleton_method(:skip_calls) { @skip_calls.to_i }
    controller.define_singleton_method(:skip_recording_studio_root_resolution) { @skip_calls = skip_calls + 1 }
    @had_runs_controller = @web_search.const_defined?(:RunsController, false)
    @original_runs_controller = @web_search.const_get(:RunsController) if @had_runs_controller
    @web_search.send(:remove_const, :RunsController) if @had_runs_controller
    @web_search.const_set(:RunsController, controller)
  end

  def gate_host
    host = Class.new do
      include RecordingStudio::WebSearch::StaffGate

      attr_accessor :actor, :performed, :authenticated, :statuses, :params

      def initialize
        @params = { anchor_url: "/admin/root" }
        @params.define_singleton_method(:to_unsafe_h) { self }
        @statuses = []
        @performed = false
        @authenticated = false
      end

      def performed?
        @performed
      end

      def head(status)
        @statuses << status
        @performed = true
      end

      def authenticate_user!
        @authenticated = true
      end

      def current_user
        actor
      end

      def view_context
        :view
      end
    end
    host.new
  end

  def restore_support!
    return unless @installed_root_switchable || @had_support

    parent = RecordingStudio::RootSwitchable
    parent.send(:remove_const, :ControllerSupport) if parent.const_defined?(:ControllerSupport, false)
    parent.const_set(:ControllerSupport, @original_support) if @had_support
    remove_const(RecordingStudio, :RootSwitchable) if @installed_root_switchable
  end

  def restore_const(parent, name, original, had)
    parent.send(:remove_const, name) if parent.const_defined?(name, false)
    parent.const_set(name, original) if had
  end

  def remove_const(parent, name)
    parent.send(:remove_const, name) if parent.const_defined?(name, false)
  end
end
