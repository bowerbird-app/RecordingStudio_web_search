# frozen_string_literal: true

RecordingStudio::WebSearch.configure do |config|
  config.provider = :brave
  config.brave_api_key = ENV.fetch("brave_search", nil)
end
