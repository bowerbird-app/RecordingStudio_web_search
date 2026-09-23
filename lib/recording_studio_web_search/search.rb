# frozen_string_literal: true

require "active_support/notifications"

module RecordingStudio
  module WebSearch
    class Search
      EVENT_NAME = "search.recording_studio_web_search"

      def self.call(query, **)
        new(query, **).call
      end

      def initialize(query, **options)
        @query_text = query
        @provider = ProviderChoice.resolve(options.delete(:provider), configuration.provider)
        @options = options
        @parameters = {}
        @request_count = 0
      end

      def call
        return perform_and_record unless configuration.instrumentation_enabled

        instrumented
      end

      private

      def instrumented
        payload = base_payload
        started = monotonic_now
        error = nil
        result = ActiveSupport::Notifications.instrument(EVENT_NAME, payload) do
          capture(payload)
        rescue Error => e
          error = fill_failure(payload, e)
        end
        finish_run(payload, started)
        error ? raise(error) : result
      end

      def perform_and_record
        payload = base_payload
        started = monotonic_now
        result = capture(payload)
        finish_run(payload, started)
        result
      rescue Error => e
        fill_failure(payload, e)
        finish_run(payload, started)
        raise
      end

      def finish_run(payload, started)
        payload[:duration_ms] = ((monotonic_now - started) * 1000).round
        RunLog.record(payload.merge(results: @result_pages || []))
      end

      def monotonic_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def capture(payload)
        result = perform
        fill_success(payload, result)
        result
      end

      def perform
        query = Query.parse(@query_text, **@options)
        @parameters = query.parameters
        provider = provider_class.new(configuration)
        response = provider.search(query)
        @request_count = 1
        response
      end

      def provider_class
        PROVIDERS.fetch(@provider) do
          raise ConfigurationError, "unknown provider: #{@provider.inspect}"
        end
      end

      def configuration
        RecordingStudio::WebSearch.configuration
      end

      def base_payload
        {
          schema_version: 1, provider: @provider, operation: :web,
          query: @query_text.to_s, parameters: {}, success: false,
          request_count: 0, estimated_cost_usd: 0, result_count: nil, error_type: nil
        }
      end

      def fill_success(payload, response)
        payload[:success] = true
        payload[:parameters] = @parameters
        payload[:request_count] = 1
        payload[:estimated_cost_usd] = cost_for(1)
        payload[:result_count] = response.results.size
        payload[:error_type] = nil
        @result_pages = ResultSnapshot.pages(response.results)
      end

      def fill_failure(payload, error)
        count = pre_http_error?(error) ? 0 : 1
        payload[:success] = false
        payload[:parameters] = @parameters
        payload[:request_count] = count
        payload[:estimated_cost_usd] = cost_for(count)
        payload[:result_count] = nil
        payload[:error_type] = error.class.name
        @result_pages = []
        error
      end

      def pre_http_error?(error)
        error.is_a?(InvalidQueryError) || error.is_a?(ConfigurationError) || error.is_a?(MissingApiKeyError)
      end

      def cost_for(request_count)
        ProviderCost.usd(@provider, configuration, request_count)
      end
    end

    module ProviderCost
      module_function

      def usd(provider, configuration, request_count)
        klass = PROVIDERS[provider]
        return 0 unless klass

        klass.new(configuration).estimated_cost_usd(request_count: request_count)
      end
    end

    module ProviderChoice
      module_function

      def resolve(value, fallback)
        chosen = value.presence || fallback
        chosen.respond_to?(:to_sym) ? chosen.to_sym : chosen
      end
    end
  end
end
