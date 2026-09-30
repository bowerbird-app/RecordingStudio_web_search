# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module RunLog
      OUTCOMES = {
        "RecordingStudio::WebSearch::MissingApiKeyError" => "Needs a key",
        "RecordingStudio::WebSearch::ConfigurationError" => "Needs a key",
        "RecordingStudio::WebSearch::Usage::ConfigurationError" => Usage::CONFIGURATION_OUTCOME,
        "RecordingStudio::WebSearch::AuthenticationError" => "Can't sign in",
        "RecordingStudio::WebSearch::RateLimitError" => "Too many requests",
        "RecordingStudio::WebSearch::TimeoutError" => "Timed out",
        "RecordingStudio::WebSearch::InvalidQueryError" => "Bad query"
      }.freeze

      module_function

      def attributes(payload)
        row = base_attributes(payload).merge(status: row_status(payload), outcome: row_outcome(payload))
        attempt_id = payload[:attempt_id]
        row[:id] = attempt_id if attempt_id
        row
      end

      def row_status(payload)
        payload[:success] == true ? "succeeded" : "failed"
      end

      def row_outcome(payload)
        return "Succeeded" if payload[:success] == true
        return Usage::DECLINED_OUTCOME if payload[:error_code] == Usage::DECLINED_CODE

        outcome_for(payload[:error_type])
      end

      def base_attributes(payload)
        {
          provider: payload[:provider].to_s,
          query: payload[:query].to_s,
          result_count: payload[:result_count],
          duration_ms: payload[:duration_ms],
          estimated_cost_usd: payload[:estimated_cost_usd].to_f,
          parameters: parameters_for(payload[:parameters]),
          results: ResultSnapshot.pages(payload[:results])
        }
      end

      def parameters_for(raw)
        return {} unless raw.is_a?(Hash)

        raw.each_with_object({}) do |(key, value), copy|
          name = key.to_s
          next if name.match?(/key|token|secret|password/i)

          copy[name] = json_value(value)
        end
      end

      def json_value(value)
        case value
        when Symbol then value.to_s
        when Hash then parameters_for(value)
        when Array then value.map { |item| json_value(item) }
        else value
        end
      end

      def outcome_for(error_type)
        OUTCOMES.fetch(error_type.to_s, "Failed")
      end

      def record(payload)
        return unless defined?(Rails) && Rails.respond_to?(:application) && Rails.application

        model = "RecordingStudio::WebSearch::SearchRun".safe_constantize
        model&.write(attributes(payload))
      end
    end
  end
end
