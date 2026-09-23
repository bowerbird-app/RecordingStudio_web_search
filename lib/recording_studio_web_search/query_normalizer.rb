# frozen_string_literal: true

require "date"

module RecordingStudio
  module WebSearch
    class QueryNormalizer
      MAX_LENGTH = 400
      COUNT_RANGE = 1..20
      PAGE_RANGE = 0..9
      SAFE_SEARCH = %w[off moderate strict].freeze
      FRESHNESS = { "day" => :day, "week" => :week, "month" => :month, "year" => :year }.freeze
      RANGE = /\A(\d{4}-\d{2}-\d{2})to(\d{4}-\d{2}-\d{2})\z/

      def text(value)
        raise InvalidQueryError, "query must be a non-blank string" unless value.is_a?(String)
        raise InvalidQueryError, "query must be a non-blank string" if value.strip.empty?
        raise InvalidQueryError, "query must be 400 characters or fewer" if value.length > MAX_LENGTH

        value
      end

      def country(value)
        return if value.nil?
        raise InvalidQueryError, "country must be a two-letter code" if value.to_s.strip.empty?

        code = value.to_s.strip.upcase
        raise InvalidQueryError, "country must be a two-letter code" unless code.match?(/\A[A-Z]{2}\z/)

        code
      end

      def language(value)
        return if value.nil?

        language = value.to_s.strip
        language.empty? ? nil : language
      end

      def count(value)
        integer_in(value, default: 10, range: COUNT_RANGE, name: "count", bounds: "1 to 20")
      end

      def page(value)
        integer_in(value, default: 0, range: PAGE_RANGE, name: "page", bounds: "0 to 9")
      end

      def safe_search(value)
        value = :moderate if value.nil?
        key = value.to_s
        raise InvalidQueryError, "safe_search must be off, moderate, or strict" unless SAFE_SEARCH.include?(key)

        key.to_sym
      end

      def freshness(value)
        return if value.nil?

        FRESHNESS[value.to_s] || range(value.to_s)
      end

      def extra_snippets(value)
        return false if value.nil?
        raise InvalidQueryError, "extra_snippets must be true or false" unless [true, false].include?(value)

        value
      end

      private

      def integer_in(value, default:, range:, name:, bounds:)
        value = default if value.nil?
        return value if value.is_a?(Integer) && range.cover?(value)

        raise InvalidQueryError, "#{name} must be an integer from #{bounds}"
      end

      def range(value)
        match = RANGE.match(value)
        raise InvalidQueryError, "freshness is invalid" unless match

        start_date = Date.iso8601(match[1])
        end_date = Date.iso8601(match[2])
        raise InvalidQueryError, "freshness range start must be on or before end" if start_date > end_date

        value
      rescue ArgumentError, TypeError
        raise InvalidQueryError, "freshness is invalid"
      end
    end
  end
end
