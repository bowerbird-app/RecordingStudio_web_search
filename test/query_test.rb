# frozen_string_literal: true

require "test_helper"

class QueryTest < Minitest::Test
  def test_defaults
    query = RecordingStudio::WebSearch::Query.parse("houses")

    assert_equal "houses", query.text
    assert_nil query.country
    assert_nil query.language
    assert_equal 10, query.count
    assert_equal 0, query.page
    assert_equal :moderate, query.safe_search
    assert_nil query.freshness
    assert_equal false, query.extra_snippets
  end

  def test_country_is_uppercased
    query = RecordingStudio::WebSearch::Query.parse("houses", country: "au")
    assert_equal "AU", query.country
  end

  def test_freshness_symbols_and_range
    assert_equal :month, RecordingStudio::WebSearch::Query.parse("q", freshness: :month).freshness
    assert_equal :week, RecordingStudio::WebSearch::Query.parse("q", freshness: "week").freshness
    assert_equal "2024-01-01to2024-01-31",
                 RecordingStudio::WebSearch::Query.parse("q", freshness: "2024-01-01to2024-01-31").freshness
  end

  def test_freshness_range_must_be_real_dates_in_order
    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", freshness: "2024-13-01to2024-13-02")
    end
    assert_includes error.message, "freshness"

    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", freshness: "2024-02-02to2024-02-01")
    end
    assert_includes error.message, "start"
  end

  def test_rejected_aliases_name_the_public_option
    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", search_lang: "en")
    end
    assert_includes error.message, "search_lang"
    assert_includes error.message, "language:"

    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", safesearch: "off")
    end
    assert_includes error.message, "safe_search:"

    error = assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", pd: true)
    end
    assert_includes error.message, "freshness:"
  end

  def test_count_and_page_bounds
    assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", count: 0)
    end
    assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", count: 21)
    end
    assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("q", page: 10)
    end
    assert_equal 20, RecordingStudio::WebSearch::Query.parse("q", count: 20).count
    assert_equal 9, RecordingStudio::WebSearch::Query.parse("q", page: 9).page
  end

  def test_query_length
    assert_raises(RecordingStudio::WebSearch::InvalidQueryError) do
      RecordingStudio::WebSearch::Query.parse("a" * 401)
    end
    assert_equal 400, RecordingStudio::WebSearch::Query.parse("a" * 400).text.length
  end
end
