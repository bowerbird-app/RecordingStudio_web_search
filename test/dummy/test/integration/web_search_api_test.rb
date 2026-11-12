# frozen_string_literal: true

require "test_helper"
require "json"
require "net/http"

class WebSearchApiTest < ActionDispatch::IntegrationTest
  setup do
    @original_key = RecordingStudio::WebSearch.configuration.brave_api_key
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"
    @owner = User.find_or_create_by!(email: "web-search-api-owner@example.com") do |account|
      account.password = "Password"
      account.password_confirmation = "Password"
    end
    @root = bootstrap_workspace!("Web Search API Workspace", @owner)
  end

  teardown do
    RecordingStudio::WebSearch.configuration.brave_api_key = @original_key
  end

  test "web_search.search returns 200 for a token with view on the root" do
    stub_search_response(
      title: "Sydney Opera House",
      url: "https://www.example.com/opera",
      description: "A landmark."
    ) do
      get "/recording_studio_api/api/v1/web_search",
          params: { query: "opera house", country: "AU" },
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "opera house", body.fetch("query")
    assert_equal "Sydney Opera House", body.fetch("results").first.fetch("title")
    refute_includes response.body, "test-brave-key"
  end

  test "web_search.search passes attribution from the request context" do
    captured = nil
    response = search_response
    original = RecordingStudio::WebSearch.method(:search)
    RecordingStudio::WebSearch.define_singleton_method(:search) do |query, **options|
      captured = [query, options]
      response
    end

    get "/recording_studio_api/api/v1/web_search",
        params: { query: "opera house" },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :success
    assert_equal "opera house", captured.first
    attribution = captured.last.fetch(:attribution)
    assert_equal @root.id, attribution.root_recording.id
  ensure
    RecordingStudio::WebSearch.define_singleton_method(:search, original) if original
  end

  test "web_search.search returns 401 without a token" do
    get "/recording_studio_api/api/v1/web_search", params: { query: "opera house" }

    assert_response :unauthorized
  end

  test "web_search.search returns 403 when the actor cannot view the root" do
    issued = issue_token_for(@owner, @root)
    RecordingStudio::Access.where(id: issued.fetch(:access_recording).recordable_id).update_all(role: "")
    refute RecordingStudioAccessible.authorized?(
      actor: issued.fetch(:access_recording).recordable.reload.actor,
      recording: @root,
      role: :view
    )

    get "/recording_studio_api/api/v1/web_search",
        params: { query: "opera house" },
        headers: bearer_headers(issued.fetch(:token))

    assert_response :forbidden
  end

  test "web_search.search returns 422 for a blank query" do
    get "/recording_studio_api/api/v1/web_search",
        params: { query: " " },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :unprocessable_entity
  end

  test "web_search.search returns 422 for an invalid country" do
    get "/recording_studio_api/api/v1/web_search",
        params: { query: "opera house", country: "USA" },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :unprocessable_entity
    body = JSON.parse(response.body)
    assert_equal "invalid_input", body.fetch("error").fetch("code")
  end

  test "web_search.search ignores a provider query param" do
    captured = nil
    response = search_response
    original = RecordingStudio::WebSearch.method(:search)
    RecordingStudio::WebSearch.define_singleton_method(:search) do |query, **options|
      captured = [query, options]
      response
    end

    get "/recording_studio_api/api/v1/web_search",
        params: { query: "opera house", provider: "paid" },
        headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))

    assert_response :success
    refute captured.last.key?(:provider)
  ensure
    RecordingStudio::WebSearch.define_singleton_method(:search, original) if original
  end

  test "web_search.search maps a provider failure to RecordingStudioApi::Error" do
    original = RecordingStudio::WebSearch.method(:search)
    RecordingStudio::WebSearch.define_singleton_method(:search) do |*|
      raise RecordingStudio::WebSearch::ProviderError.new("The search provider returned an error", status: 502)
    end

    error = assert_raises(RecordingStudioApi::Error) do
      get "/recording_studio_api/api/v1/web_search",
          params: { query: "opera house" },
          headers: bearer_headers(issue_token_for(@owner, @root).fetch(:token))
    end

    refute_instance_of RecordingStudioApi::InvalidActionInputError, error
    assert_equal "The search provider returned an error", error.message
  ensure
    RecordingStudio::WebSearch.define_singleton_method(:search, original) if original
  end

  private

  Response = Struct.new(:code, :body) do
    def [](_)
      nil
    end
  end

  def stub_search_response(title:, url:, description:)
    payload = {
      "query" => { "more_results_available" => false },
      "web" => { "results" => [{ "title" => title, "url" => url, "description" => description }] }
    }
    http = Object.new
    http.define_singleton_method(:use_ssl=) { |_| }
    http.define_singleton_method(:verify_mode=) { |_| }
    http.define_singleton_method(:open_timeout=) { |_| }
    http.define_singleton_method(:read_timeout=) { |_| }
    http.define_singleton_method(:write_timeout=) { |_| }
    http.define_singleton_method(:request) { |_| Response.new("200", JSON.generate(payload)) }

    with_net_http(->(*) { http }) { yield }
  end

  def with_net_http(factory)
    singleton = class << Net::HTTP; self; end
    original = singleton.instance_method(:new)
    singleton.define_method(:new) { |*args, **kwargs, &block| factory.call(*args, **kwargs, &block) }
    yield
  ensure
    singleton.define_method(:new, original)
  end

  def search_response
    page = RecordingStudio::WebSearch::SearchResult.new(
      title: "Opera House",
      url: "https://example.test/opera",
      description: "A house for opera",
      snippets: [],
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

  def bearer_headers(token)
    { "Authorization" => "Bearer #{token}" }
  end

  def bootstrap_workspace!(name, actor)
    workspace = Workspace.find_or_create_by!(name: name)
    root = RecordingStudio.root_recording_for(workspace)
    unless RecordingStudioAccessible.authorized?(actor: actor, recording: root, role: :view)
      RecordingStudioAccessible.bootstrap_owner_access!(recording: root, actor: actor).value!
    end
    root
  end

  def access_recording_for(actor, root)
    RecordingStudioAccessible.access_recordings_for_actor(recording: root, actor: actor).first
  end

  def issue_token_for(actor, root)
    access_recording = access_recording_for(actor, root)
    raise "missing access recording" if access_recording.blank?

    provision = RecordingStudioApi::Services::ProvisionApiClient.call(
      access_point_recording: root,
      manager_actor: actor,
      role: access_recording.recordable.role,
      name: "Web search HTTP client #{SecureRandom.hex(4)}"
    )
    raise provision.error unless provision.success?

    token_result = RecordingStudioApi::Services::IssueOauthAccessToken.call(
      grant_type: "client_credentials",
      client_id: provision.value.fetch(:credential).oauth_client_id,
      client_secret: provision.value.fetch(:token)
    )
    raise token_result.error unless token_result.success?

    {
      token: token_result.value.fetch(:access_token),
      access_recording: provision.value.fetch(:access_recording)
    }
  end
end
