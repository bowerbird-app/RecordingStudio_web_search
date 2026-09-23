# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class Configuration
      DEFAULT_OPEN_TIMEOUT = 5
      DEFAULT_READ_TIMEOUT = 10
      DEFAULT_WRITE_TIMEOUT = 5
      DEFAULT_USD_PER_1000 = 5

      attr_writer :provider, :open_timeout, :read_timeout, :write_timeout,
                  :brave_usd_per_1000_requests, :instrumentation_enabled
      attr_accessor :brave_api_key
      attr_reader :hooks

      def initialize
        @provider = :brave
        @brave_api_key = ENV.fetch("brave_search", nil)
        @open_timeout = DEFAULT_OPEN_TIMEOUT
        @read_timeout = DEFAULT_READ_TIMEOUT
        @write_timeout = DEFAULT_WRITE_TIMEOUT
        @brave_usd_per_1000_requests = DEFAULT_USD_PER_1000
        @instrumentation_enabled = true
        @hooks = RecordingStudio::Hooks.new
      end

      def provider
        value = @provider.nil? ? :brave : @provider
        value.respond_to?(:to_sym) ? value.to_sym : value
      end

      def open_timeout
        @open_timeout.nil? ? DEFAULT_OPEN_TIMEOUT : @open_timeout
      end

      def read_timeout
        @read_timeout.nil? ? DEFAULT_READ_TIMEOUT : @read_timeout
      end

      def write_timeout
        @write_timeout.nil? ? DEFAULT_WRITE_TIMEOUT : @write_timeout
      end

      def brave_usd_per_1000_requests
        @brave_usd_per_1000_requests.nil? ? DEFAULT_USD_PER_1000 : @brave_usd_per_1000_requests
      end

      def instrumentation_enabled
        @instrumentation_enabled.nil? || @instrumentation_enabled
      end

      def brave_api_key_configured?
        !brave_api_key.to_s.strip.empty?
      end

      def to_h
        {
          provider: provider,
          brave_api_key_configured: brave_api_key_configured?,
          open_timeout: open_timeout,
          read_timeout: read_timeout,
          write_timeout: write_timeout,
          brave_usd_per_1000_requests: brave_usd_per_1000_requests,
          instrumentation_enabled: instrumentation_enabled,
          hooks_registered: hooks.registered_counts
        }
      end

      def inspect
        "#<#{self.class.name} #{to_h.inspect}>"
      end

      def merge!(hash)
        return unless hash.respond_to?(:each)

        hash.each do |key, value|
          setter = "#{key}="
          public_send(setter, value) if respond_to?(setter)
        end
      end
    end
  end
end
