# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"

class AiWebSearchToolTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
    grant_admin!(@user)
  end

  test "web search is registered as an ai custom tool" do
    tool = RecordingStudioAI.tools.fetch(:web_search, version: 1)

    assert_equal "web_search", tool.key
    assert_equal 1, tool.version
    assert_equal "Web search", tool.name
    assert_equal true, tool.read_only
    assert_equal false, tool.destructive
    assert_equal false, tool.requires_confirmation
    assert_equal %w[query country language freshness count], tool.parameters.map { |parameter| parameter.fetch(:name) }
    assert_equal true, tool.parameters.first.fetch(:required)
    assert_equal false, tool.parameters.last.fetch(:required)
  end

  test "the registered tool returns the public search response" do
    tool = RecordingStudioAI.tools.fetch("web_search", version: 1)
    response = search_response
    captured = nil
    context = authorized_tool_context
    original = RecordingStudio::WebSearch.method(:search)
    RecordingStudio::WebSearch.define_singleton_method(:search) do |query, **options|
      captured = [query, options]
      response
    end

    result = tool.executor.call(
      { "query" => "opera house", "language" => "en", "freshness" => "week" },
      context
    )

    assert_equal response.to_h, result
    assert_equal ["opera house", { language: "en", freshness: "week", attribution: context }], captured
    refute_includes result_keys(response), "api_key"
  ensure
    RecordingStudio::WebSearch.define_singleton_method(:search, original) if original
  end

  test "the registered tool authorizes view and forwards attribution" do
    tool = RecordingStudioAI.tools.fetch("web_search", version: 1)
    attribution = Object.new
    recording = RecordingStudio.root_recording_for(Workspace.find_or_create_by!(name: "AI tool workspace"))
    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: @user).value! unless
      RecordingStudioAccessible.authorized?(actor: @user, recording: recording, role: :view)
    captured = nil
    user = @user
    context = Object.new
    context.define_singleton_method(:initiator) { user }
    context.define_singleton_method(:root_recording) { recording }
    context.define_singleton_method(:attribution) { attribution }
    response = search_response
    original = RecordingStudio::WebSearch.method(:search)
    RecordingStudio::WebSearch.define_singleton_method(:search) do |_query, **options|
      captured = options
      response
    end

    tool.executor.call({ "query" => "opera house" }, context)

    assert_same attribution, captured[:attribution]
  ensure
    RecordingStudio::WebSearch.define_singleton_method(:search, original) if original
  end

  test "staff can open the registered web search tool" do
    sign_in @user

    get admin_root_path

    assert_response :success
    assert_includes response.body, "Recording Studio AI"

    get staff_admin.screen_table_path("registered_custom_tools")

    assert_response :success
    assert_includes response.body, "Web search"
    assert_includes response.body, "Searches the public web and brings back titles, links, and short descriptions."
    refute_includes response.body, ENV["brave_search"].to_s if ENV["brave_search"].present?
  end

  private

  def search_response
    page = RecordingStudio::WebSearch::SearchResult.new(
      title: "Opera House",
      url: "https://example.test/opera",
      description: "A house for opera",
      snippets: ["snippet-secret"],
      published_at: nil,
      domain: "example.test",
      metadata: {}
    )
    RecordingStudio::WebSearch::SearchResponse.new(
      query: "opera house",
      provider: :brave,
      results: [page],
      metadata: {},
      more_results: false
    )
  end

  def result_keys(response)
    response.to_h.keys + response.to_h.fetch("results").flat_map(&:keys)
  end

  def authorized_tool_context
    workspace = Workspace.find_or_create_by!(name: "AI tool search workspace")
    recording = RecordingStudio.root_recording_for(workspace)
    user = @user
    unless RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :view)
      RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
    end
    context = Object.new
    context.define_singleton_method(:initiator) { user }
    context.define_singleton_method(:root_recording) { recording }
    context
  end

  def grant_admin!(user)
    admin_root = AdminRoot.find_or_create_by!(name: "Admin")
    recording = RecordingStudio.root_recording_for(admin_root)
    return if RecordingStudioAccessible.authorized?(actor: user, recording: recording, role: :view)

    RecordingStudioAccessible.bootstrap_owner_access!(recording: recording, actor: user).value!
  end
end
