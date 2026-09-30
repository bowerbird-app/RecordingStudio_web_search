# frozen_string_literal: true

require "securerandom"

module RecordingStudio
  module WebSearch
    module Usage
      DECLINED_CATEGORY = "usage"
      DECLINED_CODE = "usage_declined"
      DECLINED_OUTCOME = "Usage declined"
      CONFIGURATION_OUTCOME = "Check usage"
      OPERATION = "web"
      KEY_PREFIX = "web-search-attempt"

      class ConfigurationError < RecordingStudio::WebSearch::ConfigurationError
      end

      class Charge
        attr_reader :attempt_id, :provider, :operation, :attribution, :parameters, :quantity

        def self.for_http(provider:, attribution:, query:)
          new(
            attempt_id: SecureRandom.uuid,
            provider: provider.to_s,
            operation: OPERATION,
            attribution: attribution,
            parameters: Usage.parameter_snapshot(query),
            quantity: 1
          ).freeze
        end

        def idempotency_key
          "#{KEY_PREFIX}:#{attempt_id}"
        end

        def metadata
          {
            operation: operation,
            provider: provider,
            attempt_id: attempt_id,
            parameters: stringified_parameters
          }.freeze
        end

        def handler_arguments(key)
          {
            key: key,
            quantity: quantity,
            attribution: attribution,
            idempotency_key: idempotency_key,
            metadata: metadata
          }
        end

        private_class_method :new

        def initialize(attempt_id:, provider:, operation:, attribution:, parameters:, quantity:)
          @attempt_id = attempt_id
          @provider = provider
          @operation = operation
          @attribution = attribution
          @parameters = parameters
          @quantity = quantity
        end

        private

        def stringified_parameters
          parameters.each_with_object({}) do |pair, copy|
            name, value = pair
            copy[name.to_s] = value.is_a?(Symbol) ? value.to_s : value
          end.freeze
        end
      end

      class Meter
        attr_reader :provider, :attribution

        def initialize(provider:, attribution:)
          @provider = provider
          @attribution = attribution
          @charges = []
          @refusal = nil
        end

        def spend!(query:)
          return if configuration.usage_handler.nil?

          configuration.validate_usage_meter!
          key = usage_key(query)
          return if key.nil?

          deliver(record_charge(query), key)
        rescue ConfigurationError
          # Leave this unmarked so the run outcome stays "Check usage".
          raise
        rescue StandardError => e
          refuse(e)
        end

        def attempt_id
          @charges.first&.attempt_id
        end

        def refused?(error)
          !@refusal.nil? && @refusal.equal?(error)
        end

        private

        def deliver(charge, key)
          configuration.usage_handler.call(**charge.handler_arguments(key))
          nil
        end

        def record_charge(query)
          charge = Charge.for_http(provider: provider, attribution: attribution, query: query)
          @charges << charge
          charge
        end

        def refuse(error)
          @refusal = error
          raise error
        end

        def usage_key(query)
          key = configuration.usage_key_resolver.call(**resolver_keywords(query))
          accepted_key(key)
        end

        def resolver_keywords(query)
          {
            operation: OPERATION,
            provider: provider.to_s,
            attribution: attribution,
            parameters: Usage.parameter_snapshot(query)
          }
        end

        def accepted_key(key)
          return if key.nil?

          unless key.is_a?(String) || key.is_a?(Symbol)
            raise ConfigurationError, "usage_key_resolver must return a String, Symbol, or nil"
          end

          normalized = key.to_s
          return normalized unless normalized.strip.empty?

          raise ConfigurationError, "usage_key_resolver returned a blank key"
        end

        def configuration
          RecordingStudio::WebSearch.configuration
        end
      end

      def self.parameter_snapshot(query)
        source = query.parameters
        Query::PUBLIC_KEYWORDS.index_with { |keyword| source[keyword] }.freeze
      end
    end
  end
end
