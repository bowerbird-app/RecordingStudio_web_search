# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class Query
      PUBLIC_KEYWORDS = %i[country language count page safe_search freshness extra_snippets].freeze
      ALIASES = {
        offset: "offset: is not supported; use page:",
        search_lang: "search_lang: is not supported; use language:",
        safesearch: "safesearch: is not supported; use safe_search:",
        pd: "pd: is not supported; use freshness:",
        pw: "pw: is not supported; use freshness:",
        pm: "pm: is not supported; use freshness:",
        py: "py: is not supported; use freshness:"
      }.freeze

      attr_reader :text, :country, :language, :count, :page, :safe_search, :freshness, :extra_snippets

      def self.parse(text, **)
        new(text, **)
      end

      def initialize(text, **options)
        reject_keywords!(options)
        assign_options(text, options)
      end

      def parameters
        {
          country: country,
          language: language,
          count: count,
          page: page,
          safe_search: safe_search,
          freshness: freshness,
          extra_snippets: extra_snippets
        }
      end

      private

      def assign_options(text, options)
        normalizer = QueryNormalizer.new
        @text = normalizer.text(text)
        PUBLIC_KEYWORDS.each do |key|
          instance_variable_set(:"@#{key}", normalizer.public_send(key, options[key]))
        end
      end

      def reject_keywords!(options)
        ALIASES.each { |key, message| raise InvalidQueryError, message if options.key?(key) }
        unknown = options.keys - PUBLIC_KEYWORDS
        raise InvalidQueryError, "unknown keyword: #{unknown.first}" if unknown.any?
      end
    end
  end
end
