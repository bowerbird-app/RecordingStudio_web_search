# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminI18nRenderTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
  end

  test "admin section and screens render english chrome without proc leakage" do
    sign_in @user

    get staff_admin.section_path("web_search", anchor_url: admin_root_path)
    assert_response :success
    assert_includes response.body, "Web search"
    assert_includes response.body, "See who searches, what failed, and what it cost."
    assert_includes response.body, "View providers"
    assert_includes response.body, "View searches"
    assert_includes response.body, "Providers"
    assert_includes response.body, "Failures"
    refute_includes response.body, "#<Proc"

    get staff_admin.screen_path("web_search_providers")
    assert_response :success
    assert_includes response.body, "Providers"
    assert_includes response.body, "Who can answer a search."
    refute_includes response.body, "#<Proc"

    get staff_admin.screen_path("web_search_runs")
    assert_response :success
    assert_includes response.body, "Searches"
    assert_includes response.body, "Every search that left this app."
    assert_includes response.body, "Log"
    refute_includes response.body, "#<Proc"
  end

  test "admin dsl keeps screen subtitles and table title as english string literals" do
    providers = RecordingStudio::WebSearch::Admin::ProvidersScreen
    searches = RecordingStudio::WebSearch::Admin::SearchesScreen

    assert_equal "Who can answer a search.", providers.subtitle
    assert_equal "Every search that left this app.", searches.subtitle
    refute_respond_to providers.subtitle, :call
    refute_respond_to searches.subtitle, :call

    table_title = searches.table_value.title_value
    assert_equal "Log", table_title
    refute_respond_to table_title, :call
  end

  test "admin dsl titles resolve to english strings via evaluate" do
    context = RecordingStudioAdmin::Context.new(
      params: {},
      current_actor: @user,
      controller: nil,
      routes: nil,
      view_context: nil
    )

    section = RecordingStudio::WebSearch::Admin::WebSearchSection
    assert_equal "Web search", section.evaluate(section.title, context)
    assert_equal "See who searches, what failed, and what it cost.",
                 section.evaluate(section.subtitle, context)

    providers = RecordingStudio::WebSearch::Admin::ProvidersScreen
    assert_equal "Providers", providers.evaluate(providers.title, context)

    searches = RecordingStudio::WebSearch::Admin::SearchesScreen
    assert_equal "Searches", searches.evaluate(searches.title, context)
  end

  private

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(recording: recording, actor: user, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
