# frozen_string_literal: true

require "test_helper"

class ApiTest < Minitest::Test
  def test_register_is_a_noop_when_api_is_unavailable
    refute defined?(RecordingStudioApi)

    assert_nil RecordingStudio::WebSearch::HostBoot.register_api!
  end

  def test_gemspec_omits_runtime_recording_studio_api_dependency
    gemspec = File.read(File.expand_path("../recording_studio_web_search.gemspec", __dir__))

    refute_includes gemspec, 'spec.add_dependency "recording_studio_api"'
    refute_includes gemspec, 'spec.add_development_dependency "recording_studio_api"'
  end

  def test_engine_registers_api_when_present
    engine = File.read(File.expand_path("../lib/recording_studio_web_search/engine.rb", __dir__))
    api = File.read(File.expand_path("../lib/recording_studio_web_search/api.rb", __dir__))
    contract = File.read(File.expand_path("../lib/recording_studio_web_search/api/contract.rb", __dir__))
    search = File.read(File.expand_path("../lib/recording_studio_web_search/api/search.rb", __dir__))
    boot = File.read(File.expand_path("../lib/recording_studio_web_search/host_boot.rb", __dir__))

    assert_includes engine, 'initializer "recording_studio_web_search.api"'
    assert_includes engine, "HostBoot.register_api!"
    assert_includes boot, "require \"recording_studio_web_search/api\""
    assert_includes boot, "Api.register!"
    assert_includes api, "RecordingStudioApi.register_endpoint"
    assert_includes api, "each_api"
    assert_includes contract, "reject_unknown: false"
    assert_includes api, "This gem adds no MCP tools."
    assert_includes search, "access_grant.authorize!"
    assert_includes search, "attribution:"
    assert_includes search, "RecordingStudio::WebSearch.search"
  end
end
