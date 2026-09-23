# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class Error < StandardError; end
    class ConfigurationError < Error; end
    class MissingApiKeyError < Error; end
    class InvalidQueryError < Error; end

    class ProviderError < Error
      attr_reader :status

      def initialize(message = nil, status: nil)
        @status = status
        super(message)
      end
    end

    class AuthenticationError < ProviderError; end

    class RateLimitError < ProviderError
      attr_reader :retry_after

      def initialize(message = nil, status: 429, retry_after: nil)
        @retry_after = retry_after
        super(message, status: status)
      end
    end

    class InvalidResponseError < ProviderError; end
    class NetworkError < ProviderError; end
    class TimeoutError < NetworkError; end
  end
end
