# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class HostLocaleOverrideTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  HOST_SEARCHES_LABEL = "Host searches label"

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
    @locale_path = Rails.root.join("config/locales/en.yml")
    @original_locale = File.read(@locale_path)
  end

  teardown do
    File.write(@locale_path, @original_locale)
    I18n.reload!
  end

  test "host config/locales override wins on the run show page" do
    File.write(@locale_path, <<~YAML)
      en:
        hello: "Hello world"
        recording_studio:
          web_search:
            runs:
              searches: "#{HOST_SEARCHES_LABEL}"
    YAML
    I18n.reload!

    sign_in @user
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "host override run",
      status: "failed",
      outcome: "Needs a key",
      estimated_cost_usd: 0,
      parameters: {},
      results: []
    )

    get recording_studio_web_search.run_path(run)

    assert_response :success
    assert_includes response.body, HOST_SEARCHES_LABEL
    refute_includes response.body, ">Searches<"
    assert_select "a", text: HOST_SEARCHES_LABEL
    assert_includes response.body, "Nothing came back."
  end

  private

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(recording: recording, actor: user, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
