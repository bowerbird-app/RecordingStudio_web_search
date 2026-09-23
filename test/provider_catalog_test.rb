# frozen_string_literal: true

require "test_helper"

class ProviderCatalogTest < Minitest::Test
  def setup
    @original = RecordingStudio::WebSearch.instance_variable_get(:@configuration)
    RecordingStudio::WebSearch.instance_variable_set(
      :@configuration,
      RecordingStudio::WebSearch::Configuration.new
    )
  end

  def teardown
    RecordingStudio::WebSearch.instance_variable_set(:@configuration, @original)
  end

  def test_lists_each_configured_provider
    RecordingStudio::WebSearch.configuration.brave_api_key = nil

    rows = RecordingStudio::WebSearch::ProviderCatalog.rows

    assert_equal ["Brave"], rows.map(&:name)
    assert_equal "Needs a key", rows.first.status
    assert_equal 0, rows.first.searches
    assert_equal "$0.000", rows.first.spent
  end

  def test_brave_is_ready_when_a_key_is_configured
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"

    status = RecordingStudio::WebSearch::ProviderCatalog.rows.first.status

    assert_equal "Ready", status
  end

  def test_relation_filters_sorts_and_limits
    catalog = RecordingStudio::WebSearch::ProviderCatalog
    rows = [
      catalog::Row.new(name: "Brave", status: "Ready", searches: 2, spent: "$0.010"),
      catalog::Row.new(name: "Other", status: "Needs a key", searches: 10, spent: "$0.050")
    ]
    relation = catalog::Relation.new(rows)

    page = relation.where(status: "Ready").order(searches: "desc").limit(1).to_a

    assert_equal ["Brave"], page.map(&:name)
    assert_equal 2, relation.count
    assert_equal %w[Other Brave], relation.order(searches: "desc").to_a.map(&:name)
  end

  def test_labels_multiword_provider_names
    assert_equal "Brave", RecordingStudio::WebSearch::ProviderCatalog.label_for(:brave)
    assert_equal "Example Search", RecordingStudio::WebSearch::ProviderCatalog.label_for("example_search")
  end
end
