# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_PAGES_NOT_KEPT = "Host kept none of these pages."
  HOST_FAILURES_INFO = "HOST searches that did not come back."
  OVERRIDE_LOCALE = Rails.root.join("test/fixtures/locales/web_search_host_override.en.yml").to_s
  BOOT_HOST_LOCALE = Rails.root.join("config/locales/recording_studio_web_search_host.en.yml")
  BOOT_OVERRIDE_KEY = "recording_studio.web_search.admin.widgets.failures.info"

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
    @original_load_path = I18n.load_path.dup
    @original_backend = I18n.backend
  end

  teardown do
    I18n.backend = @original_backend
    I18n.load_path.replace(@original_load_path)
    I18n.reload!
  end

  test "host test-only locale override wins for the pages-not-kept empty state" do
    I18n.load_path |= [OVERRIDE_LOCALE]
    I18n.reload!

    sign_in @user
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "pages dropped for host override",
      status: "succeeded",
      outcome: "Succeeded",
      result_count: 3,
      estimated_cost_usd: 0.005,
      parameters: {},
      results: []
    )

    get recording_studio_web_search.run_path(run)

    assert_response :success
    assert_includes response.body, HOST_PAGES_NOT_KEPT
    refute_includes response.body, "These pages were not kept."
    assert_includes response.body, "Searches"
    assert_select "a", text: "Searches"
  end

  # Real-boot-order guard: host file under config/locales must win without any
  # test-time load_path mutation.
  test "boot-loaded host locale override wins for failures widget info on a real page" do
    assert File.exist?(BOOT_HOST_LOCALE), "expected boot host override at #{BOOT_HOST_LOCALE}"
    assert_includes File.read(BOOT_HOST_LOCALE), HOST_FAILURES_INFO
    assert_equal HOST_FAILURES_INFO, I18n.t(BOOT_OVERRIDE_KEY)
    assert_equal @original_load_path, I18n.load_path,
                 "boot-order test must not mutate I18n.load_path"

    sign_in @user
    get staff_admin.section_widget_path("web_search", "widgets.web_search.failures")

    assert_response :success
    assert_includes response.body, HOST_FAILURES_INFO
    refute_includes response.body, "Searches that did not come back."
    assert_includes response.body, "Failures"
  end

  private

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(recording: recording, actor: user, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
