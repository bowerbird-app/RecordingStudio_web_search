# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_PAGES_NOT_KEPT = "Host kept none of these pages."
  OVERRIDE_LOCALE = Rails.root.join("test/fixtures/locales/web_search_host_override.en.yml").to_s

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
    @original_load_path = I18n.load_path.dup
  end

  teardown do
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

  private

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(recording: recording, actor: user, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
