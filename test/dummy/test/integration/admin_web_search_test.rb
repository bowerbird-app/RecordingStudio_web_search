# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AdminWebSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_key = RecordingStudio::WebSearch.configuration.brave_api_key
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
  end

  teardown do
    RecordingStudio::WebSearch.configuration.brave_api_key = @original_key
  end

  test "admin root lists the web search section" do
    sign_in @user

    get root_path
    assert_response :success
    assert_select "a[href='#{admin_root_path}']", text: "Admin"
    assert_includes response.body, "@hotwired/turbo-rails"

    get admin_root_path

    assert_response :success
    assert_includes response.body, "Staff tools for this site."
    assert_includes response.body, "Web search"
    section_href = "#{staff_admin.section_path('web_search')}?anchor_url=#{CGI.escape(admin_root_path)}"
    assert_select "a[href='#{section_href}']"
  end

  test "web search section links to providers and searches" do
    sign_in @user

    anchor = admin_root_path
    get staff_admin.section_path("web_search", anchor_url: anchor)

    assert_response :success
    assert_select "a[href='#{anchor}']"
    assert_includes response.body, "View providers"
    assert_includes response.body, "View searches"
    assert_includes response.body, "Providers"
    assert_includes response.body, "Failures"
  end

  test "providers screen lists brave and never the api key" do
    sign_in @user
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"

    get staff_admin.screen_table_path("web_search_providers")

    assert_response :success
    assert_includes response.body, "Brave"
    assert_includes response.body, "Ready"
    refute_includes response.body, "test-brave-key"
  end

  test "searches screen shows spend, status, and the failed filter" do
    sign_in @user
    RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "opera house",
      status: "succeeded",
      outcome: "Succeeded",
      result_count: 1,
      estimated_cost_usd: 0.005,
      parameters: {}
    )
    RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "missing houses",
      status: "failed",
      outcome: "Needs a key",
      estimated_cost_usd: 0,
      parameters: {}
    )

    get staff_admin.screen_path("web_search_runs")
    assert_response :success
    assert_includes response.body, "Searches"
    assert_includes response.body, "Provider"
    assert_includes response.body, "Status"
    assert_select "input[name='start_date'][value='#{Date.current - 27}']"
    assert_select "input[name='end_date'][value='#{Date.current}']"

    get staff_admin.screen_chart_path("web_search_runs")
    assert_response :success
    assert_includes response.body, "Searches"
    refute_includes response.body, "Spend"
    refute_includes response.body, "Last 27 days"

    opera = RecordingStudio::WebSearch::SearchRun.find_by!(query: "opera house")
    missing = RecordingStudio::WebSearch::SearchRun.find_by!(query: "missing houses")

    get staff_admin.screen_table_path("web_search_runs")
    assert_response :success
    assert_includes response.body, "opera house"
    assert_includes response.body, "Succeeded"
    assert_includes response.body, "Needs a key"
    assert_includes response.body, "Brave"
    assert_select "a[href='#{recording_studio_web_search.run_path(opera)}']", text: "1"
    assert_select "a[href='#{recording_studio_web_search.run_path(missing)}']", text: "None"

    get staff_admin.screen_table_path("web_search_runs", status: "failed")
    assert_response :success
    assert_includes response.body, "missing houses"
    assert_includes response.body, "Needs a key"
    refute_includes response.body, "opera house"
  end

  test "failures widget links to failed searches" do
    sign_in @user

    get staff_admin.section_widget_path("web_search", "widgets.web_search.failures")

    assert_response :success
    assert_includes response.body, "Failures"
    assert_includes response.body, "status=failed"
  end

  test "a failed search is logged without storing a key" do
    sign_in @user
    RecordingStudio::WebSearch.configuration.brave_api_key = nil

    assert_difference -> { RecordingStudio::WebSearch::SearchRun.count }, 1 do
      get root_path, params: { q: "logged failure" }
    end

    run = RecordingStudio::WebSearch::SearchRun.order(:created_at).last
    assert_equal "failed", run.status
    assert_equal "Needs a key", run.outcome
    assert_equal "logged failure", run.query
    assert_equal [], run.results
    refute_includes run.parameters.to_json, "api_key"
  end

  test "results count opens the saved pages" do
    sign_in @user
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "opera house",
      status: "succeeded",
      outcome: "Succeeded",
      result_count: 1,
      estimated_cost_usd: 0.005,
      parameters: {},
      results: [
        {
          "title" => "Sydney Opera House",
          "url" => "https://www.example.com/opera",
          "domain" => "example.com",
          "description" => "A landmark.",
          "snippets" => ["snippet-secret"]
        }
      ]
    )
    failed = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "missing houses",
      status: "failed",
      outcome: "Needs a key",
      estimated_cost_usd: 0,
      parameters: { brave_api_key: "test-brave-key" },
      results: []
    )

    get recording_studio_web_search.run_path(run)

    assert_response :success
    assert_includes response.body, "Sydney Opera House"
    assert_includes response.body, "example.com"
    assert_includes response.body, "A landmark."
    assert_includes response.body, "Succeeded"
    assert_select "a[href='https://www.example.com/opera']"
    assert_select "a[href='/admin/screens/web_search_runs']", text: "Searches"
    refute_includes response.body, "snippet-secret"
    refute_includes response.body, "test-brave-key"

    get recording_studio_web_search.run_path(failed)

    assert_response :success
    assert_includes response.body, "Needs a key"
    assert_includes response.body, "Nothing came back."
    refute_includes response.body, "Sydney Opera House"
    refute_includes response.body, "test-brave-key"
  end

  test "a search show page keeps the anchor and ignores a selected workspace" do
    sign_in @user
    anchor = admin_root_path
    Workspace.create!(name: "Current Workspace")
    get root_path
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "kept pages",
      status: "succeeded",
      outcome: "Succeeded",
      result_count: 0,
      estimated_cost_usd: 0,
      parameters: {},
      results: []
    )

    get "/addons/recording/runs/#{run.id}", params: { anchor_url: anchor }

    assert_response :success
    assert_includes response.body, "Nothing turned up."
    assert_select "a[href='#{anchor}']"
  end

  test "search show page requires an access grant" do
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "private search",
      status: "succeeded",
      outcome: "Succeeded",
      result_count: 0,
      estimated_cost_usd: 0,
      parameters: {},
      results: []
    )
    outsider = User.create!(
      email: "outsider-show@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in outsider

    get recording_studio_web_search.run_path(run)

    assert_response :forbidden
  end

  test "search show page requires sign in" do
    run = RecordingStudio::WebSearch::SearchRun.create!(
      provider: "brave",
      query: "signed out search",
      status: "failed",
      outcome: "Failed",
      estimated_cost_usd: 0,
      parameters: {},
      results: []
    )

    get recording_studio_web_search.run_path(run)

    assert_redirected_to new_user_session_path
  end

  test "admin screens require an access grant" do
    outsider = User.create!(
      email: "outsider@example.com",
      password: "Password",
      password_confirmation: "Password"
    )
    sign_in outsider

    get admin_root_path
    assert_response :forbidden

    get staff_admin.root_path
    assert_response :forbidden
  end

  test "admin stays available when a workspace is the current root" do
    sign_in @user
    Workspace.create!(name: "Current Workspace")

    get root_path
    assert_response :success

    get admin_root_path
    assert_response :success
    assert_includes response.body, "Web search"

    get staff_admin.root_path
    assert_response :success
    assert_includes response.body, "View providers"
  end

  test "admin root requires sign in" do
    get admin_root_path

    assert_redirected_to new_user_session_path
  end

  private

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(recording: recording, actor: user, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
