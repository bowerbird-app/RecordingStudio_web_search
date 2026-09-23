# frozen_string_literal: true

require "test_helper"

class RunLogTest < Minitest::Test
  def test_success_attributes_keep_public_parameters_only
    attributes = RecordingStudio::WebSearch::RunLog.attributes(
      success: true,
      provider: :brave,
      query: "houses",
      result_count: 2,
      duration_ms: 10,
      estimated_cost_usd: 0.005,
      parameters: { count: 10, safe_search: :moderate, brave_api_key: "secret-key" },
      error_type: nil
    )

    assert_equal "brave", attributes[:provider]
    assert_equal "succeeded", attributes[:status]
    assert_equal "Succeeded", attributes[:outcome]
    assert_equal 2, attributes[:result_count]
    assert_in_delta 0.005, attributes[:estimated_cost_usd]
    assert_equal "moderate", attributes[:parameters]["safe_search"]
    assert_equal 10, attributes[:parameters]["count"]
    refute_includes attributes[:parameters].values, "secret-key"
  end

  def test_known_failures_use_plain_outcomes
    outcomes = {
      "RecordingStudio::WebSearch::MissingApiKeyError" => "Needs a key",
      "RecordingStudio::WebSearch::ConfigurationError" => "Needs a key",
      "RecordingStudio::WebSearch::AuthenticationError" => "Can't sign in",
      "RecordingStudio::WebSearch::RateLimitError" => "Too many requests",
      "RecordingStudio::WebSearch::TimeoutError" => "Timed out",
      "RecordingStudio::WebSearch::InvalidQueryError" => "Bad query",
      "RecordingStudio::WebSearch::NetworkError" => "Failed"
    }

    outcomes.each do |error_type, outcome|
      attributes = RecordingStudio::WebSearch::RunLog.attributes(
        success: false,
        provider: :brave,
        query: "houses",
        estimated_cost_usd: 0,
        parameters: {},
        error_type: error_type
      )

      assert_equal "failed", attributes[:status]
      assert_equal outcome, attributes[:outcome]
    end
  end

  def test_record_does_nothing_without_a_rails_application
    assert_nil RecordingStudio::WebSearch::RunLog.record(
      success: false,
      provider: :brave,
      query: "houses",
      estimated_cost_usd: 0,
      parameters: {}
    )
  end
end
