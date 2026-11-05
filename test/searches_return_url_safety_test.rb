# frozen_string_literal: true

require "test_helper"

class SearchesReturnUrlSafetyTest < Minitest::Test
  def teardown
    restore_admin_mount_path!
  end

  def test_anchor_url_uses_real_admin_url_safety_and_rejects_external_urls
    load_real_admin_url_safety!

    source = RecordingStudioAdmin::UrlSafety.method(:safe_href).source_location.first
    assert_includes source, "url_safety.rb"
    refute_includes source, "staff_pages_test"

    assert_equal "/admin/root", RecordingStudioAdmin::UrlSafety.safe_href("/admin/root", allow_external: false)
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("https://evil.test", allow_external: false)
    assert_equal "#", RecordingStudioAdmin::UrlSafety.safe_href("//evil.test/phish", allow_external: false)

    assert_equal "/admin/root", RecordingStudio::WebSearch::SearchesReturn.anchor_url("/admin/root")
    assert_nil RecordingStudio::WebSearch::SearchesReturn.anchor_url("https://evil.test")
    assert_nil RecordingStudio::WebSearch::SearchesReturn.anchor_url("//evil.test/phish")
    assert_equal "/staff/screens/web_search_runs", RecordingStudio::WebSearch::SearchesReturn.path("https://evil.test")
  end

  private

  module StaffMountConfiguration
    def configuration
      @configuration ||= Struct.new(:default_mount_path).new("/staff")
    end
  end

  def load_real_admin_url_safety!
    path = admin_url_safety_path
    skip "recording_studio_admin is not installed in the dummy bundle" if path.nil?

    require path
    ensure_staff_mount_path!
  end

  def ensure_staff_mount_path!
    unless RecordingStudioAdmin.respond_to?(:configuration)
      RecordingStudioAdmin.extend(StaffMountConfiguration)
      return
    end

    config = RecordingStudioAdmin.configuration
    @original_mount_path = config.default_mount_path
    @restored_mount_path = true
    config.default_mount_path = "/staff"
  end

  def restore_admin_mount_path!
    return unless @restored_mount_path
    return unless defined?(RecordingStudioAdmin) && RecordingStudioAdmin.respond_to?(:configuration)

    RecordingStudioAdmin.configuration.default_mount_path = @original_mount_path
  end

  def admin_url_safety_path
    spec = Gem.loaded_specs["recording_studio_admin"]
    if spec
      file = File.join(spec.full_gem_path, "lib/recording_studio_admin/url_safety.rb")
      return file if File.exist?(file)
    end

    studio = Gem.loaded_specs["recording_studio"]
    return unless studio

    pattern = "../RecordingStudio_admin-*/lib/recording_studio_admin/url_safety.rb"
    Dir.glob(File.expand_path(pattern, studio.full_gem_path)).first
  end
end
