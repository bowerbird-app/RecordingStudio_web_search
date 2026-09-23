# frozen_string_literal: true

require "uri"

module RecordingStudio
  module WebSearch
    module ResultSnapshot
      FIELDS = %w[title url domain description].freeze

      module_function

      def pages(results)
        Array(results).filter_map { |result| page(result) }
      end

      def page(result)
        source = hash_for(result)
        return unless source

        built = FIELDS.index_with { |field| field == "url" ? http_url(source[field]) : text(source[field]) }
        built unless built.values.all?(&:nil?)
      end

      def hash_for(result)
        return stringify(result) if result.is_a?(Hash)
        return stringify(result.to_h) if result.respond_to?(:to_h)

        nil
      end

      def stringify(hash)
        hash.to_h.transform_keys(&:to_s)
      end

      def text(value)
        return if value.nil?

        value.to_s
      end

      def http_url(value)
        uri = URI.parse(value.to_s)
        return unless uri.is_a?(URI::HTTP) && uri.host

        uri.to_s
      rescue URI::InvalidURIError
        nil
      end
    end
  end
end
