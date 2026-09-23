# frozen_string_literal: true

require "net/http"
require "openssl"
require "socket"
require "timeout"

module RecordingStudio
  module WebSearch
    module Providers
      class Brave
        def initialize(configuration)
          @configuration = configuration
        end

        def search(query)
          assert_api_key!
          request = BraveRequest.new(query, @configuration.brave_api_key)
          map(query, perform(request))
        end

        def estimated_cost_usd(request_count:)
          count = request_count.to_i
          return 0 if count <= 0

          count * (@configuration.brave_usd_per_1000_requests.to_f / 1000.0)
        end

        private

        def assert_api_key!
          return unless @configuration.brave_api_key.to_s.strip.empty?

          raise MissingApiKeyError, "Brave API key is missing"
        end

        def perform(request)
          http = Net::HTTP.new(request.uri.host, request.uri.port)
          configure_http(http)
          http.request(request.http_request)
        rescue Timeout::Error
          raise TimeoutError, "The search request timed out"
        rescue SocketError, OpenSSL::SSL::SSLError, IOError, SystemCallError
          raise NetworkError, "The search request could not be completed"
        end

        def configure_http(http)
          http.use_ssl = true
          http.verify_mode = OpenSSL::SSL::VERIFY_PEER
          http.open_timeout = @configuration.open_timeout
          http.read_timeout = @configuration.read_timeout
          http.write_timeout = @configuration.write_timeout
        end

        def map(query, response)
          BraveMapper.new(estimated_cost_usd(request_count: 1)).map(query, response)
        end
      end
    end
  end
end
