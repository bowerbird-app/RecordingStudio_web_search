# frozen_string_literal: true

require "test_helper"

class UsageTest < Minitest::Test
  include WebSearchHttpStub

  ATTEMPT_KEY = /\Aweb-search-attempt:[0-9a-f-]{36}\z/

  def setup
    @original = RecordingStudio::WebSearch.instance_variable_get(:@configuration)
    RecordingStudio::WebSearch.instance_variable_set(:@configuration, RecordingStudio::WebSearch::Configuration.new)
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"
    @events = []
    @subscriber = ActiveSupport::Notifications.subscribe("search.recording_studio_web_search") do |*args|
      @events << ActiveSupport::Notifications::Event.new(*args)
    end
    @logged = nil
    @resolver_calls = 0
    @handler_calls = 0
    @handler_calls_list = []
    @resolver_call = nil
  end

  def teardown
    ActiveSupport::Notifications.unsubscribe(@subscriber)
    RecordingStudio::WebSearch.instance_variable_set(:@configuration, @original)
  end

  def test_search_without_a_handler_skips_the_resolver
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_raising("resolver should not run")

    response = nil
    stub_net_http(response: json_response(success_body)) do |captured|
      response = RecordingStudio::WebSearch.search("Australian architecture")

      assert_equal 1, captured[:calls]
    end

    assert_equal 0, @resolver_calls
    assert_equal "A", response.results.first.title
    refute last_payload.key?(:attempt_id)
    refute last_payload.key?(:error_code)
    refute last_payload.key?(:error_category)
  end

  def test_metered_brave_search_charges_once_before_http
    attribution = Object.new
    response = nil
    track_log do
      stub_net_http(response: json_response(sydney_body)) do |captured|
        RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("web.brave")
        RecordingStudio::WebSearch.configuration.usage_handler = handler_recording do
          captured[:order] << :handler
        end
        response = RecordingStudio::WebSearch.search(
          "Australian architecture",
          country: "AU",
          language: "en",
          count: 10,
          page: 1,
          safe_search: "strict",
          freshness: "month",
          extra_snippets: true,
          attribution: attribution
        )

        assert_equal %i[handler request], captured[:order]
        assert_equal 1, captured[:calls]
      end
    end

    seen = @handler_calls_list.first
    assert_equal "Sydney Opera House", response.results.first.title
    assert_equal :brave, response.provider
    assert_equal "web.brave", seen[:key]
    assert_equal 1, seen[:quantity]
    assert_instance_of Integer, seen[:quantity]
    assert_same attribution, seen[:attribution]
    assert_match ATTEMPT_KEY, seen[:idempotency_key]
    assert_equal "web", @resolver_call[:operation]
    assert_equal "brave", @resolver_call[:provider]
    assert_same attribution, @resolver_call[:attribution]
    assert_equal(
      {
        country: "AU", language: "en", count: 10, page: 1,
        safe_search: :strict, freshness: :month, extra_snippets: true
      },
      @resolver_call[:parameters]
    )
    assert @resolver_call[:parameters].frozen?
    assert_equal "web", seen[:metadata][:operation]
    assert_equal "brave", seen[:metadata][:provider]
    assert_equal seen[:idempotency_key].split(":", 2).last, seen[:metadata][:attempt_id]
    assert_equal(
      {
        "country" => "AU", "language" => "en", "count" => 10, "page" => 1,
        "safe_search" => "strict", "freshness" => "month", "extra_snippets" => true
      },
      seen[:metadata][:parameters]
    )
    assert seen[:metadata].frozen?
    assert seen[:metadata][:parameters].frozen?
    refute_includes seen[:metadata].inspect, "Australian architecture"
    assert_equal 1, last_payload[:request_count]
    assert_equal seen[:metadata][:attempt_id], last_payload[:attempt_id]
    refute last_payload.key?(:error_code)
    assert_equal "succeeded", run_attributes[:status]
    assert_equal "Succeeded", run_attributes[:outcome]
    assert_equal seen[:metadata][:attempt_id], run_attributes[:id]
  end

  def test_handler_runtime_error_is_a_usage_decline_without_http
    boom = RuntimeError.new("credits exhausted")
    install_brave_meter(handler_raising(boom))

    error = nil
    track_log do
      stub_net_http(response: json_response(success_body)) do |captured|
        error = assert_raises(RuntimeError) do
          RecordingStudio::WebSearch.search("houses", attribution: Object.new)
        end
        assert_equal 0, captured[:calls]
      end
    end

    seen_key = @handler_calls_list.first[:idempotency_key]
    assert_same boom, error
    assert_equal "credits exhausted", error.message
    assert_equal false, last_payload[:success]
    assert_equal 0, last_payload[:request_count]
    assert_equal 0, last_payload[:estimated_cost_usd]
    assert_nil last_payload[:result_count]
    assert_equal "RuntimeError", last_payload[:error_type]
    assert_equal "usage", last_payload[:error_category]
    assert_equal "usage_declined", last_payload[:error_code]
    assert_equal seen_key.split(":", 2).last, last_payload[:attempt_id]
    assert_equal [], @logged[:results]
    assert_equal "failed", run_attributes[:status]
    assert_equal "Usage declined", run_attributes[:outcome]
    assert_equal seen_key.split(":", 2).last, run_attributes[:id]
    refute run_attributes.key?(:error_category)
    refute run_attributes.key?(:error_code)
    refute run_attributes.key?(:error_type)
    refute run_attributes.key?(:attempt_id)
    refute run_attributes.key?(:attribution)
  end

  def test_handler_runtime_error_without_instrumentation_is_the_same_object
    RecordingStudio::WebSearch.configuration.instrumentation_enabled = false
    boom = RuntimeError.new("credits exhausted")
    install_brave_meter(handler_raising(boom))

    error = nil
    track_log do
      stub_net_http(response: json_response(success_body)) do |captured|
        error = assert_raises(RuntimeError) { RecordingStudio::WebSearch.search("houses") }
        assert_equal 0, captured[:calls]
      end
    end

    assert_same boom, error
    assert_empty @events
    assert_equal "Usage declined", run_attributes[:outcome]
    assert_equal "failed", run_attributes[:status]
  end

  def test_handler_io_error_is_not_remapped_to_a_network_error
    boom = IOError.new("billing down")
    install_brave_meter(handler_raising(boom))

    error = nil
    stub_net_http(response: json_response(success_body)) do |captured|
      error = assert_raises(IOError) { RecordingStudio::WebSearch.search("houses") }
      assert_equal 0, captured[:calls]
    end

    assert_same boom, error
    assert_instance_of IOError, error
  end

  def test_nil_resolver_key_searches_without_calling_the_handler
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning(nil)
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    response = nil
    stub_net_http(response: json_response(sydney_body)) do |captured|
      response = RecordingStudio::WebSearch.search("museum openings")
      assert_equal 1, captured[:calls]
    end

    assert_nil @resolver_call[:attribution]
    assert_equal 0, @handler_calls
    assert_equal "Sydney Opera House", response.results.first.title
    refute last_payload.key?(:attempt_id)
  end

  def test_two_searches_mint_two_attempt_keys
    stub_net_http(response: json_response(success_body)) do |captured|
      RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("web.brave")
      RecordingStudio::WebSearch.configuration.usage_handler = handler_recording do
        captured[:order] << :handler
      end
      RecordingStudio::WebSearch.search("one")
      RecordingStudio::WebSearch.search("two")

      assert_equal 2, captured[:calls]
      assert_equal %i[handler request handler request], captured[:order]
    end

    keys = @handler_calls_list.map { |call| call[:idempotency_key] }
    assert_equal 2, keys.size
    refute_equal keys[0], keys[1]
    assert_match ATTEMPT_KEY, keys[0]
    assert_match ATTEMPT_KEY, keys[1]
  end

  def test_spend_twice_mints_two_charges
    host_attribution = Object.new
    meter = RecordingStudio::WebSearch::Usage::Meter.new(provider: :brave, attribution: host_attribution)
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("web.brave")
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording
    query = RecordingStudio::WebSearch::Query.parse("houses")

    meter.spend!(query: query)
    meter.spend!(query: query)

    keys = @handler_calls_list.map { |call| call[:idempotency_key] }
    assert_equal([1, 1], @handler_calls_list.map { |call| call[:quantity] })
    assert_equal 2, keys.uniq.size
    assert_match ATTEMPT_KEY, keys[0]
    assert_match ATTEMPT_KEY, keys[1]
    assert_equal keys[0].split(":", 2).last, meter.attempt_id
    refute_equal meter.attempt_id, keys[1].split(":", 2).last
    assert_same host_attribution, @handler_calls_list.first[:attribution]
    assert_same host_attribution, @handler_calls_list.last[:attribution]
  end

  def test_charge_idempotency_key_is_stable
    query = RecordingStudio::WebSearch::Query.parse("houses", safe_search: "moderate")
    charge = RecordingStudio::WebSearch::Usage::Charge.for_http(provider: :brave, attribution: nil, query: query)
    first = charge.idempotency_key
    second = charge.idempotency_key

    assert_equal first, second
    assert_match ATTEMPT_KEY, first
    assert charge.frozen?
    assert_equal :moderate, charge.parameters[:safe_search]
    assert_equal "moderate", charge.metadata[:parameters]["safe_search"]
  end

  def test_missing_api_key_does_not_meter_or_open_a_socket
    RecordingStudio::WebSearch.configuration.brave_api_key = " "
    install_brave_meter(handler_recording)

    stub_net_http(response: json_response(success_body)) do |captured|
      error = assert_raises(RecordingStudio::WebSearch::MissingApiKeyError) do
        RecordingStudio::WebSearch.search("Australian architecture")
      end
      assert_equal "Brave API key is missing", error.message
      assert_equal 0, captured[:calls]
    end

    assert_equal 0, @resolver_calls
    assert_equal 0, @handler_calls
  end

  def test_invalid_query_does_not_meter
    install_brave_meter(handler_recording)

    stub_net_http(response: json_response(success_body)) do |captured|
      assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
        RecordingStudio::WebSearch.search("   ")
      end
      assert_equal 0, captured[:calls]
    end

    assert_equal 0, @resolver_calls
    assert_equal 0, @handler_calls
  end

  def test_unknown_provider_does_not_meter
    RecordingStudio::WebSearch.configuration.provider = :bing
    install_brave_meter(handler_recording)

    stub_net_http(response: json_response(success_body)) do |captured|
      error = assert_raises(RecordingStudio::WebSearch::ConfigurationError) do
        RecordingStudio::WebSearch.search("q")
      end
      assert_includes error.message, "unknown provider"
      assert_equal 0, captured[:calls]
    end

    assert_equal 0, @resolver_calls
    assert_equal 0, @handler_calls
  end

  def test_blank_resolver_key_is_check_usage_and_does_not_call_http
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("  ")
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    error = nil
    track_log do
      stub_net_http(response: json_response(success_body)) do |captured|
        error = assert_raises(RecordingStudio::WebSearch::Usage::ConfigurationError) do
          RecordingStudio::WebSearch.search("houses")
        end
        assert_equal 0, captured[:calls]
      end
    end

    assert_equal 0, @handler_calls
    assert_equal "usage_key_resolver returned a blank key", error.message
    assert_equal 0, last_payload[:request_count]
    assert_equal 0, last_payload[:estimated_cost_usd]
    refute last_payload.key?(:attempt_id)
    refute last_payload.key?(:error_code)
    assert_equal "Check usage", run_attributes[:outcome]
    assert_equal "failed", run_attributes[:status]
    refute run_attributes.key?(:id)
  end

  def test_provider_timeout_after_the_handler_is_not_a_usage_decline
    install_brave_meter(handler_recording)

    error = nil
    track_log do
      stub_net_http(error: Net::OpenTimeout.new("execution expired")) do |captured|
        error = assert_raises(RecordingStudio::WebSearch::TimeoutError) do
          RecordingStudio::WebSearch.search("houses")
        end
        assert_equal 1, captured[:calls]
      end
    end

    attempt_key = @handler_calls_list.first[:idempotency_key]
    assert_equal 1, @handler_calls
    assert_instance_of RecordingStudio::WebSearch::TimeoutError, error
    assert_equal "The search request timed out", error.message
    assert_equal 1, last_payload[:request_count]
    assert_equal attempt_key.split(":", 2).last, last_payload[:attempt_id]
    refute last_payload.key?(:error_code)
    assert_equal "Timed out", run_attributes[:outcome]
    assert_equal "failed", run_attributes[:status]
    assert_equal attempt_key.split(":", 2).last, run_attributes[:id]
  end

  def test_metadata_omits_query_text_and_api_key
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("web.brave")
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    stub_net_http(response: json_response(success_body)) do
      RecordingStudio::WebSearch.search("secret-query-text", country: "AU")
    end

    metadata = @handler_calls_list.first[:metadata]
    refute_includes metadata.inspect, "secret-query-text"
    refute_includes metadata.inspect, "test-brave-key"
    refute_includes @resolver_call[:parameters].inspect, "secret-query-text"
    refute_includes @resolver_call[:parameters].inspect, "test-brave-key"
    refute metadata[:parameters].key?("q")
    refute @resolver_call[:parameters].key?(:text)
  end

  def test_resolver_runtime_error_is_declined_without_a_charge
    boom = RuntimeError.new("resolver down")
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_raising(boom)
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    error = nil
    track_log do
      stub_net_http(response: json_response(success_body)) do |captured|
        error = assert_raises(RuntimeError) { RecordingStudio::WebSearch.search("houses") }
        assert_equal 0, captured[:calls]
      end
    end

    assert_same boom, error
    assert_equal 0, @handler_calls
    assert_equal "usage", last_payload[:error_category]
    assert_equal "usage_declined", last_payload[:error_code]
    refute last_payload.key?(:attempt_id)
    assert_equal "Usage declined", run_attributes[:outcome]
    refute run_attributes.key?(:id)
  end

  def test_non_string_resolver_key_is_not_a_refusal
    meter = RecordingStudio::WebSearch::Usage::Meter.new(provider: :brave, attribution: nil)
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning(1)
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording
    query = RecordingStudio::WebSearch::Query.parse("houses")

    error = assert_raises(RecordingStudio::WebSearch::Usage::ConfigurationError) do
      meter.spend!(query: query)
    end

    assert_equal "usage_key_resolver must return a String, Symbol, or nil", error.message
    assert_equal 0, @handler_calls
    refute meter.refused?(error)
    assert_nil meter.attempt_id
  end

  def test_symbol_key_reaches_the_handler_as_a_string
    meter = RecordingStudio::WebSearch::Usage::Meter.new(provider: :brave, attribution: nil)
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning(:web_brave)
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    meter.spend!(query: RecordingStudio::WebSearch::Query.parse("houses"))

    assert_equal "web_brave", @handler_calls_list.first[:key]
  end

  def test_blank_symbol_key_is_a_configuration_error
    meter = RecordingStudio::WebSearch::Usage::Meter.new(provider: :brave, attribution: nil)
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning(:" ")
    RecordingStudio::WebSearch.configuration.usage_handler = handler_recording

    error = assert_raises(RecordingStudio::WebSearch::Usage::ConfigurationError) do
      meter.spend!(query: RecordingStudio::WebSearch::Query.parse("houses"))
    end

    assert_equal "usage_key_resolver returned a blank key", error.message
    assert_equal 0, @handler_calls
    refute meter.refused?(error)
  end

  def test_library_and_gemspec_do_not_name_stripe
    root = File.expand_path("..", __dir__)
    paths = Dir.glob(File.join(root, "lib/**/*.rb"))
    paths << File.join(root, "recording_studio_web_search.gemspec")

    paths.each do |path|
      refute_includes File.read(path), "RecordingStudioStripe", path
    end
  end

  private

  def install_brave_meter(handler)
    RecordingStudio::WebSearch.configuration.usage_key_resolver = resolver_returning("web.brave")
    RecordingStudio::WebSearch.configuration.usage_handler = handler
  end

  def resolver_returning(key)
    lambda do |provider:, operation:, attribution:, parameters:|
      @resolver_calls += 1
      @resolver_call = { provider: provider, operation: operation, attribution: attribution, parameters: parameters }
      key
    end
  end

  def resolver_raising(error)
    lambda do |provider:, operation:, attribution:, parameters:|
      @resolver_calls += 1
      @resolver_call = { provider: provider, operation: operation, attribution: attribution, parameters: parameters }
      raise error
    end
  end

  def handler_recording(&block)
    lambda do |key:, quantity:, attribution:, idempotency_key:, metadata:|
      @handler_calls += 1
      call = {
        key: key, quantity: quantity, attribution: attribution,
        idempotency_key: idempotency_key, metadata: metadata
      }
      @handler_calls_list << call
      block&.call
      "ignored"
    end
  end

  def handler_raising(error)
    lambda do |key:, quantity:, attribution:, idempotency_key:, metadata:|
      @handler_calls += 1
      @handler_calls_list << {
        key: key, quantity: quantity, attribution: attribution,
        idempotency_key: idempotency_key, metadata: metadata
      }
      raise error
    end
  end

  def track_log(&block)
    RecordingStudio::WebSearch::RunLog.stub(:record, ->(payload) { @logged = payload }) do
      block.call
    end
  end

  def run_attributes
    RecordingStudio::WebSearch::RunLog.attributes(@logged)
  end

  def last_payload
    @events.last.payload
  end

  def success_body
    {
      "query" => { "original" => "q" },
      "web" => { "results" => [{ "title" => "A", "url" => "https://example.com" }] }
    }
  end

  def sydney_body
    {
      "query" => { "original" => "q" },
      "web" => {
        "results" => [
          {
            "title" => "Sydney Opera House",
            "url" => "https://www.example.com/opera",
            "description" => "A landmark."
          }
        ]
      }
    }
  end
end
