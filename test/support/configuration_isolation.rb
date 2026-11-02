# frozen_string_literal: true

module WebSearchConfigurationIsolation
  CONFIG_FIELDS = %i[
    provider
    brave_api_key
    open_timeout
    read_timeout
    write_timeout
    brave_usd_per_1000_requests
    instrumentation_enabled
    usage_handler
    usage_key_resolver
  ].freeze

  def snapshot_web_search_configuration
    config = RecordingStudio::WebSearch.configuration
    CONFIG_FIELDS.to_h { |name| [name, config.public_send(name)] }
  end

  def restore_web_search_configuration(snapshot)
    return if snapshot.nil?

    config = RecordingStudio::WebSearch.configuration
    snapshot.each { |name, value| config.public_send("#{name}=", value) }
  end

  def reset_web_search_configuration_to_defaults
    config = RecordingStudio::WebSearch.configuration
    defaults = RecordingStudio::WebSearch::Configuration.new
    CONFIG_FIELDS.each { |name| config.public_send("#{name}=", defaults.public_send(name)) }
  end
end
