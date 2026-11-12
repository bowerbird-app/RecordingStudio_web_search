# frozen_string_literal: true

require "test_helper"

class AiToolTest < Minitest::Test
  def test_register_does_nothing_until_recording_studio_ai_is_loaded
    refute defined?(RecordingStudioAI)

    assert_nil RecordingStudio::WebSearch::AiTool.register!
  end

  def test_register_sends_the_web_search_contract
    with_fake_ai do |tools|
      assert_equal :registered, RecordingStudio::WebSearch::AiTool.register!

      kwargs = tools.kwargs
      assert_equal :web_search, kwargs[:key]
      assert_equal 1, kwargs[:version]
      assert_equal true, kwargs[:override]
      assert_equal true, kwargs[:read_only]
      assert_equal false, kwargs[:destructive]
      names = kwargs[:parameters].map { |parameter| parameter[:name].to_s }
      assert_equal %w[query country language freshness count], names
    end
  end

  def test_executor_returns_the_search_response_and_forwards_only_given_options
    response = search_response
    captured = nil
    search = lambda do |query, **options|
      captured = [query, options]
      response
    end
    context = authorized_context

    RecordingStudio::WebSearch.stub(:search, search) do
      result = RecordingStudio::WebSearch::AiTool::DEFINITION.fetch(:executor).call(
        { "query" => "opera house", "country" => "AU", "count" => 2 },
        context
      )

      assert_equal response.to_h, result
    end

    assert_equal ["opera house", { country: "AU", count: 2, attribution: context }], captured
  end

  def test_executor_omits_optional_arguments_that_were_not_sent
    captured = nil
    search = lambda do |query, **options|
      captured = [query, options]
      search_response
    end
    context = authorized_context

    RecordingStudio::WebSearch.stub(:search, search) do
      RecordingStudio::WebSearch::AiTool.execute({ "query" => "opera house" }, context)
    end

    assert_equal ["opera house", { attribution: context }], captured
  end

  def test_executor_authorizes_view_on_the_root_and_passes_context_attribution
    attribution = Object.new
    recording = Object.new
    authorized = nil
    captured = nil
    context = Object.new
    grant = Object.new
    grant.define_singleton_method(:authorize!) do |recording:, role:, **|
      authorized = [recording, role]
    end
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:root_recording) { recording }
    context.define_singleton_method(:attribution) { attribution }
    search = lambda do |_query, **options|
      captured = options
      search_response
    end

    RecordingStudio::WebSearch.stub(:search, search) do
      RecordingStudio::WebSearch::AiTool.execute({ "query" => "opera house" }, context)
    end

    assert_equal [recording, :view], authorized
    assert_same attribution, captured[:attribution]
  end

  def test_executor_denies_when_the_access_grant_is_not_authorized
    grant = Object.new
    grant.define_singleton_method(:authorize!) do |**|
      raise "API access grant is not authorized for this capability"
    end
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:root_recording) { Object.new }
    called = false

    RecordingStudio::WebSearch.stub(:search, ->(*) { called = true }) do
      error = assert_raises(RuntimeError) do
        RecordingStudio::WebSearch::AiTool.execute({ "query" => "opera house" }, context)
      end

      assert_match(/not authorized/, error.message)
    end

    refute called
  end

  private

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

  def authorized_context
    grant = Object.new
    grant.define_singleton_method(:authorize!) { |**| true }
    context = Object.new
    context.define_singleton_method(:access_grant) { grant }
    context.define_singleton_method(:root_recording) { Object.new }
    context
  end

  def with_fake_ai
    tools = FakeTools.new
    fake = Module.new
    fake.define_singleton_method(:tools) { tools }
    Object.const_set(:RecordingStudioAI, fake)
    yield tools
  ensure
    Object.send(:remove_const, :RecordingStudioAI) if defined?(RecordingStudioAI)
  end

  class FakeTools
    attr_reader :kwargs

    def register(**kwargs)
      @kwargs = kwargs
      :registered
    end
  end
end
