# frozen_string_literal: true

# Usage metering stays off until usage_key_resolver and usage_handler are both set.
# The README shows the host handler.
RecordingStudio::WebSearch.configure do |config|
  config.provider = :brave
  config.brave_api_key = ENV.fetch("brave_search", nil)
  # nil uses RecordingStudio.configuration.layout, then recording_studio/default_layout.
  # config.layout = "recording_studio/default_layout"
end
