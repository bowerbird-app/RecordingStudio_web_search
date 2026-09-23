# frozen_string_literal: true

require "test_helper"

class SearchTest < Minitest::Test
  include WebSearchHttpStub

  def setup
    @original = RecordingStudio::WebSearch.instance_variable_get(:@configuration)
    RecordingStudio::WebSearch.instance_variable_set(:@configuration, RecordingStudio::WebSearch::Configuration.new)
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe("search.recording_studio_web_search") do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    RecordingStudio::WebSearch.instance_variable_set(:@configuration, @original)
  end

  def test_search_returns_literal_result_fields
    body = success_body(
      more: true,
      results: [
        {
          "title" => "Sydney Opera House",
          "url" => "https://www.example.com/opera",
          "description" => "A landmark.",
          "page_age" => "2024-03-15T12:00:00Z",
          "age" => "a year ago",
          "meta_url" => { "hostname" => "wrong.example" }
        }
      ]
    )

    stub_net_http(response: json_response(body)) do |_captured|
      response = RecordingStudio::WebSearch.search("Australian architecture")

      assert_equal "Australian architecture", response.query
      assert_equal :brave, response.provider
      assert_equal true, response.more_results?
      assert_equal 1, response.results.size

      result = response.results.first
      assert_equal "Sydney Opera House", result.title
      assert_equal "https://www.example.com/opera", result.url
      assert_equal "example.com", result.domain
      assert_equal "A landmark.", result.description
      assert_equal [], result.snippets
      assert_equal Time.iso8601("2024-03-15T12:00:00Z"), result.published_at
      assert_equal "a year ago", result.metadata[:age]
      refute result.metadata.key?(:raw)
    end
  end

  def test_nil_description_empty_snippets_and_unparseable_page_age
    body = success_body(
      results: [
        {
          "title" => "Untitled",
          "url" => "https://architecture.org.au/page",
          "description" => "",
          "page_age" => "last Tuesday"
        }
      ]
    )

    stub_net_http(response: json_response(body)) do
      result = RecordingStudio::WebSearch.search("houses").results.first

      assert_nil result.description
      assert_equal [], result.snippets
      assert_nil result.published_at
      assert_equal "architecture.org.au", result.domain
    end
  end

  def test_decoration_markup_is_plain_text
    body = success_body(
      results: [
        {
          "title" => "BowerBird &amp; Co",
          "url" => "https://bowerbird.io/app",
          "description" => "Get your <strong>architecture</strong> published",
          "extra_snippets" => ["Get your <strong>architecture</strong> published", "Offices in Brooklyn &amp; Hudson"]
        }
      ]
    )

    stub_net_http(response: json_response(body)) do
      result = RecordingStudio::WebSearch.search("decorations", extra_snippets: true).results.first

      assert_equal "BowerBird & Co", result.title
      assert_equal "Get your architecture published", result.description
      assert_equal ["Offices in Brooklyn & Hudson"], result.snippets
    end
  end

  def test_extra_snippets_do_not_duplicate_description
    body = success_body(
      results: [
        {
          "title" => "Guide",
          "url" => "https://example.net/guide",
          "description" => "Main text",
          "extra_snippets" => ["Main text", "More context"]
        }
      ]
    )

    stub_net_http(response: json_response(body)) do
      result = RecordingStudio::WebSearch.search("guide", extra_snippets: true).results.first

      assert_equal ["More context"], result.snippets
    end
  end

  def test_more_results_is_true_only_for_exact_true
    body = success_body(more: "true")

    stub_net_http(response: json_response(body)) do
      refute RecordingStudio::WebSearch.search("q").more_results?
    end
  end

  def test_brave_request_maps_public_options
    body = success_body

    stub_net_http(response: json_response(body)) do |captured|
      RecordingStudio::WebSearch.search(
        "Australian architecture",
        country: "au",
        language: "en",
        freshness: "month",
        count: 10,
        page: 0,
        safe_search: "moderate"
      )

      request = captured[:request]
      params = request_params(request)

      assert_equal "api.search.brave.com", captured[:host]
      assert_equal "/res/v1/web/search", URI.parse("https://x#{request.path}").path
      assert_equal "Australian architecture", params["q"]
      assert_equal "AU", params["country"]
      assert_equal "en", params["search_lang"]
      assert_equal "0", params["offset"]
      assert_equal "10", params["count"]
      assert_equal "moderate", params["safesearch"]
      assert_equal "pm", params["freshness"]
      assert_equal "false", params["text_decorations"]
      refute params.key?("extra_snippets")
      assert request["X-Subscription-Token"]
      assert_equal "application/json", request["Accept"]
      assert_equal true, captured[:use_ssl]
      assert_equal OpenSSL::SSL::VERIFY_PEER, captured[:verify_mode]
    end
  end

  def test_page_1_sends_offset_1_and_does_not_request_page_2
    body = success_body(more: true)

    stub_net_http(response: json_response(body)) do |captured|
      response = RecordingStudio::WebSearch.search("paged", page: 1)

      assert_equal "1", request_params(captured[:request])["offset"]
      assert_equal true, response.more_results?
      assert_equal 1, captured[:calls]
    end
  end

  def test_extra_snippets_true_is_sent
    stub_net_http(response: json_response(success_body)) do |captured|
      RecordingStudio::WebSearch.search("q", extra_snippets: true)

      assert_equal "true", request_params(captured[:request])["extra_snippets"]
    end
  end

  def test_missing_key_does_not_open_a_socket
    RecordingStudio::WebSearch.configuration.brave_api_key = "  "
    called = false
    Net::HTTP.stub(:new, lambda { |*|
      called = true
      raise "socket opened"
    }) do
      error = assert_raises(RecordingStudio::WebSearch::MissingApiKeyError) do
        RecordingStudio::WebSearch.search("Australian architecture")
      end
      assert_equal "Brave API key is missing", error.message
    end
    refute called
  end

  def test_unknown_provider_raises_before_http
    RecordingStudio::WebSearch.configuration.provider = :bing
    called = false
    Net::HTTP.stub(:new, ->(*) { called = true }) do
      error = assert_raises(RecordingStudio::WebSearch::ConfigurationError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_includes error.message, "unknown provider"
      assert_includes error.message, "bing"
    end
    refute called
  end

  def test_provider_brave_is_selected
    stub_net_http(response: json_response(success_body)) do
      response = RecordingStudio::WebSearch.search("q")
      assert_equal :brave, response.provider
    end
  end

  def test_provider_keyword_overrides_configuration
    RecordingStudio::WebSearch.configuration.provider = :bing
    stub_net_http(response: json_response(success_body)) do
      response = RecordingStudio::WebSearch.search("q", provider: :brave)
      assert_equal :brave, response.provider
    end
    assert_equal :brave, last_payload[:provider]
  end

  def test_authentication_error_on_401
    stub_net_http(response: json_response({ "error" => "nope" }, status: 401)) do
      error = assert_raises(RecordingStudio::WebSearch::AuthenticationError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_equal 401, error.status
      refute_includes error.message, "nope"
      refute_includes error.message, "test-brave-key"
    end
  end

  def test_rate_limit_error_parses_retry_after
    stub_net_http(response: json_response("slow", status: 429, headers: { "Retry-After" => "30" })) do
      error = assert_raises(RecordingStudio::WebSearch::RateLimitError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_equal 429, error.status
      assert_equal 30, error.retry_after
      refute_includes error.message, "slow"
    end
  end

  def test_timeout_error_from_transport
    stub_net_http(error: Net::OpenTimeout.new("execution expired")) do
      error = assert_raises(RecordingStudio::WebSearch::TimeoutError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_equal "The search request timed out", error.message
      refute_includes error.message, "Net::OpenTimeout"
    end
  end

  def test_invalid_query_empty
    called = false
    Net::HTTP.stub(:new, ->(*) { called = true }) do
      error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
        RecordingStudio::WebSearch.search("   ")
      end
      assert_includes error.message, "non-blank"
    end
    refute called
  end

  def test_unknown_keyword_is_named
    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch.search("q", type: "news")
    end
    assert_includes error.message, "type"
  end

  def test_offset_is_rejected
    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch.search("q", offset: 1)
    end
    assert_includes error.message, "offset"
    assert_includes error.message, "page:"
  end

  def test_bad_json_is_invalid_response
    stub_net_http(response: json_response("not-json", status: 200)) do
      error = assert_raises(RecordingStudio::WebSearch::InvalidResponseError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_equal 200, error.status
    end
  end

  def test_missing_web_hash_is_invalid_response
    stub_net_http(response: json_response({ "query" => {} })) do
      assert_raises(RecordingStudio::WebSearch::InvalidResponseError) do
        RecordingStudio::WebSearch.search("q")
      end
    end
  end

  def test_cost_is_0_005_after_a_sent_request
    stub_net_http(response: json_response(success_body)) do
      response = RecordingStudio::WebSearch.search("q")
      assert_in_delta 0.005, response.metadata[:estimated_cost_usd], 0.0000001
    end
    assert_in_delta 0.005, last_payload[:estimated_cost_usd], 0.0000001
  end

  def test_cost_is_zero_before_http
    RecordingStudio::WebSearch.configuration.brave_api_key = nil

    assert_raises(RecordingStudio::WebSearch::MissingApiKeyError) do
      RecordingStudio::WebSearch.search("q")
    end
    assert_equal 0, last_payload[:request_count]
    assert_equal 0, last_payload[:estimated_cost_usd]
  end

  def test_cost_override
    RecordingStudio::WebSearch.configuration.brave_usd_per_1000_requests = 10
    stub_net_http(response: json_response(success_body)) do
      response = RecordingStudio::WebSearch.search("q")
      assert_in_delta 0.01, response.metadata[:estimated_cost_usd], 0.0000001
    end
  end

  def test_failed_sent_request_still_costs
    stub_net_http(response: json_response("nope", status: 401)) do
      assert_raises(RecordingStudio::WebSearch::AuthenticationError) do
        RecordingStudio::WebSearch.search("q")
      end
    end
    assert_equal 1, last_payload[:request_count]
    assert_in_delta 0.005, last_payload[:estimated_cost_usd], 0.0000001
  end

  def test_notification_success_payload
    results = [{ "title" => "A", "url" => "https://a.test" }, { "title" => "B", "url" => "https://b.test" }]
    stub_net_http(response: json_response(success_body(results: results))) do
      RecordingStudio::WebSearch.search("Australian architecture", country: "AU", count: 10)
    end

    payload = last_payload
    assert_equal 1, payload[:schema_version]
    assert_equal :brave, payload[:provider]
    assert_equal :web, payload[:operation]
    assert_equal "Australian architecture", payload[:query]
    assert_equal "AU", payload[:parameters][:country]
    assert_equal 10, payload[:parameters][:count]
    assert_equal 0, payload[:parameters][:page]
    assert_equal :moderate, payload[:parameters][:safe_search]
    assert_equal false, payload[:parameters][:extra_snippets]
    assert_equal true, payload[:success]
    assert_equal 1, payload[:request_count]
    assert_in_delta 0.005, payload[:estimated_cost_usd], 0.0000001
    assert_equal 2, payload[:result_count]
    assert_nil payload[:error_type]
    refute payload.key?(:exception_object)
    refute payload.key?(:results)
    refute_includes payload.inspect, "test-brave-key"
    assert last_event.duration
  end

  def test_notification_failure_payload
    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch.search("")
    end
    assert_instance_of RecordingStudio::WebSearch::InvalidQueryError, error

    payload = last_payload
    assert_equal false, payload[:success]
    assert_equal 0, payload[:request_count]
    assert_equal 0, payload[:estimated_cost_usd]
    assert_nil payload[:result_count]
    assert_equal "RecordingStudio::WebSearch::InvalidQueryError", payload[:error_type]
    refute payload.key?(:exception_object)
    refute payload.key?(:exception)
    refute payload.key?(:results)
  end

  def test_log_snapshot_keeps_public_page_fields
    logged = nil
    results = [
      {
        "title" => "Sydney Opera House",
        "url" => "https://www.example.com/opera",
        "description" => "A landmark."
      }
    ]
    RecordingStudio::WebSearch::RunLog.stub(:record, ->(payload) { logged = payload }) do
      stub_net_http(response: json_response(success_body(results: results))) do
        RecordingStudio::WebSearch.search("Australian architecture")
      end
    end

    page = logged[:results].first
    assert_equal "Sydney Opera House", page["title"]
    assert_equal "https://www.example.com/opera", page["url"]
    assert_equal "example.com", page["domain"]
    assert_equal "A landmark.", page["description"]
    assert_equal %w[title url domain description], page.keys
    refute last_payload.key?(:results)
    refute_includes logged.inspect, "test-brave-key"
  end

  def test_failed_log_snapshot_is_empty
    logged = nil
    RecordingStudio::WebSearch::RunLog.stub(:record, ->(payload) { logged = payload }) do
      assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
        RecordingStudio::WebSearch.search("")
      end
    end

    assert_equal [], logged[:results]
    refute last_payload.key?(:results)
  end

  def test_disabled_instrumentation_still_logs_a_failure
    RecordingStudio::WebSearch.configuration.instrumentation_enabled = false
    logged = nil
    RecordingStudio::WebSearch::RunLog.stub(:record, ->(payload) { logged = payload }) do
      assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
        RecordingStudio::WebSearch.search("")
      end
    end

    assert_equal [], logged[:results]
    assert_empty @events
  end

  def test_instrumentation_can_be_disabled
    RecordingStudio::WebSearch.configuration.instrumentation_enabled = false
    stub_net_http(response: json_response(success_body)) do
      RecordingStudio::WebSearch.search("q")
    end
    assert_empty @events
  end

  def test_to_h_is_json_safe
    body = success_body(
      results: [
        {
          "title" => "Opera",
          "url" => "https://example.com/opera",
          "description" => "A landmark.",
          "page_age" => "2024-03-15T12:00:00Z"
        }
      ]
    )

    stub_net_http(response: json_response(body)) do
      hash = RecordingStudio::WebSearch.search("q").to_h
      assert_equal "q", hash["query"]
      assert_equal "brave", hash["provider"]
      assert_equal false, hash["more_results"]
      assert_equal "2024-03-15T12:00:00Z", hash["results"].first["published_at"]
      assert hash["metadata"].key?("estimated_cost_usd")
      JSON.generate(hash)
    end
  end

  private

  def success_body(more: false, results: [{ "title" => "A", "url" => "https://example.com" }])
    {
      "query" => { "original" => "q", "more_results_available" => more },
      "web" => { "results" => results }
    }
  end

  def last_event
    @events.last
  end

  def last_payload
    last_event.payload
  end
end
