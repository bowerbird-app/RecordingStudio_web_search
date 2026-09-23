# frozen_string_literal: true

require "test_helper"
require "devise/test/integration_helpers"
require "json"
require "net/http"

class HomeSearchTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_key = RecordingStudio::WebSearch.configuration.brave_api_key
    RecordingStudio::WebSearch.configuration.brave_api_key = "test-brave-key"
    @user = User.find_or_create_by!(email: "admin@admin.com") do |record|
      record.password = "Password"
      record.password_confirmation = "Password"
    end
  end

  teardown do
    RecordingStudio::WebSearch.configuration.brave_api_key = @original_key
  end

  test "home search requires sign in" do
    get root_path

    assert_redirected_to new_user_session_path
  end

  test "blank query renders the form and does not call search" do
    sign_in @user
    called = false

    with_net_http(->(*) { called = true }) do
      get root_path
    end

    assert_response :success
    assert_select "form[method='get'][action='/']"
    assert_select "input[name='q']"
    assert_select "select[name='provider'] option", text: "Brave"
    assert_includes response.body, "Query"
    assert_includes response.body, "Provider"
    assert_includes response.body, "Search"
    refute called
    refute_includes response.body, "Brave API key is missing"
  end

  test "search error shows the gem message" do
    sign_in @user
    RecordingStudio::WebSearch.configuration.brave_api_key = nil

    get root_path, params: { q: "Australian architecture" }

    assert_response :success
    assert_includes response.body, "Brave API key is missing"
    refute_includes response.body, "test-brave-key"
  end

  test "search results render a card per result" do
    sign_in @user
    stub_search_response(
      title: "Sydney Opera House",
      url: "https://www.example.com/opera",
      description: "A landmark."
    ) do
      get root_path, params: { q: "Australian architecture" }
    end

    assert_response :success
    assert_select "a[href='https://www.example.com/opera']", text: "Sydney Opera House"
    assert_includes response.body, "example.com"
    assert_includes response.body, "A landmark."
    refute_includes response.body, "test-brave-key"
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
end
