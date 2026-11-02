# frozen_string_literal: true

module WebSearchConfigurationIsolation
  def self.writable_fields
    writers = RecordingStudio::WebSearch::Configuration.public_instance_methods(false).grep(/=\z/)
    writers.map { |name| name.to_s.delete_suffix("=").to_sym }.sort
  end

  def snapshot_web_search_configuration
    config = RecordingStudio::WebSearch.configuration
    WebSearchConfigurationIsolation.writable_fields.to_h { |name| [name, config.public_send(name)] }
  end

  def restore_web_search_configuration(snapshot)
    return if snapshot.nil?

    config = RecordingStudio::WebSearch.configuration
    snapshot.each { |name, value| config.public_send("#{name}=", value) }
  end

  def reset_web_search_configuration_to_defaults
    config = RecordingStudio::WebSearch.configuration
    defaults = RecordingStudio::WebSearch::Configuration.new
    WebSearchConfigurationIsolation.writable_fields.each do |name|
      config.public_send("#{name}=", defaults.public_send(name))
    end
  end
end
