# frozen_string_literal: true

require "recording_studio"
require "recording_studio_web_search/version"
require "recording_studio_web_search/errors"
require "recording_studio_web_search/configuration"
require "recording_studio_web_search/search_result"
require "recording_studio_web_search/search_response"
require "recording_studio_web_search/query_normalizer"
require "recording_studio_web_search/query"
require "recording_studio_web_search/providers/brave_request"
require "recording_studio_web_search/providers/brave_time"
require "recording_studio_web_search/providers/brave_mapper"
require "recording_studio_web_search/providers/brave"
require "recording_studio_web_search/search"
require "recording_studio_web_search/engine"

module RecordingStudio
  module WebSearch
    PROVIDERS = { brave: RecordingStudio::WebSearch::Providers::Brave }.freeze
    private_constant :PROVIDERS

    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration) if block_given?
      end

      def search(query, **)
        Search.call(query, **)
      end
    end
  end
end
