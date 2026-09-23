# frozen_string_literal: true

require "test_helper"

class ConfigurationTest < Minitest::Test
  def setup
    @configuration = RecordingStudio::WebSearch::Configuration.new
  end

  def test_defaults
    assert_equal :brave, @configuration.provider
    assert_equal 5, @configuration.open_timeout
    assert_equal 10, @configuration.read_timeout
    assert_equal 5, @configuration.write_timeout
    assert_equal 5, @configuration.brave_usd_per_1000_requests
    assert_equal true, @configuration.instrumentation_enabled
    assert_instance_of RecordingStudio::Hooks, @configuration.hooks
  end

  def test_timeouts_never_nil
    @configuration.open_timeout = nil
    @configuration.read_timeout = nil
    @configuration.write_timeout = nil

    assert_equal 5, @configuration.open_timeout
    assert_equal 10, @configuration.read_timeout
    assert_equal 5, @configuration.write_timeout
  end

  def test_initialize_uses_env_brave_search_key
    previous = ENV.fetch("brave_search", nil)
    ENV["brave_search"] = "env-configured-key"

    configuration = RecordingStudio::WebSearch::Configuration.new

    assert_equal "env-configured-key", configuration.brave_api_key
    assert_equal true, configuration.to_h[:brave_api_key_configured]
    refute_includes configuration.to_h.keys, :brave_api_key
    refute_includes configuration.inspect, "env-configured-key"
  ensure
    if previous.nil?
      ENV.delete("brave_search")
    else
      ENV["brave_search"] = previous
    end
  end

  def test_to_h_redacts_api_key
    @configuration.brave_api_key = "super-secret-token"
    result = @configuration.to_h

    assert_equal true, result[:brave_api_key_configured]
    refute_includes result.keys, :brave_api_key
    refute_includes result.inspect, "super-secret-token"
    refute_includes @configuration.inspect, "super-secret-token"
  end

  def test_to_h_reports_unconfigured_key
    @configuration.brave_api_key = "  "

    assert_equal false, @configuration.to_h[:brave_api_key_configured]
  end

  def test_merge_updates_known_attributes
    @configuration.merge!(provider: :brave, open_timeout: 9, instrumentation_enabled: false)

    assert_equal :brave, @configuration.provider
    assert_equal 9, @configuration.open_timeout
    assert_equal false, @configuration.instrumentation_enabled
  end

  def test_merge_ignores_unknown_keys
    @configuration.merge!(unknown_key: "ignored", read_timeout: 7)

    refute_respond_to @configuration, :unknown_key
    assert_equal 7, @configuration.read_timeout
  end

  def test_merge_with_non_enumerable_is_noop
    original = @configuration.to_h

    @configuration.merge!(nil)

    assert_equal original, @configuration.to_h
  end

  def test_merge_accepts_string_keys
    @configuration.merge!("open_timeout" => 12, "provider" => "brave")

    assert_equal 12, @configuration.open_timeout
    assert_equal :brave, @configuration.provider
  end

  def test_to_h_reports_registered_hook_counts
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.before_initialize { nil }
    @configuration.hooks.after_service { nil }

    result = @configuration.to_h

    assert_equal 2, result.fetch(:hooks_registered).fetch(:before_initialize)
    assert_equal 1, result.fetch(:hooks_registered).fetch(:after_service)
  end

  def test_configure_without_block_is_safe
    RecordingStudio::WebSearch.configure

    assert_kind_of RecordingStudio::WebSearch::Configuration, RecordingStudio::WebSearch.configuration
  end
end
