# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    SearchResponse = Data.define(:query, :provider, :results, :metadata, :more_results) do
      def more_results?
        more_results == true
      end

      def to_h
        {
          "query" => query,
          "provider" => provider.to_s,
          "results" => results.map(&:to_h),
          "metadata" => stringify_keys(metadata),
          "more_results" => more_results?
        }
      end

      private

      def stringify_keys(value)
        value.to_h.transform_keys(&:to_s)
      end
    end
  end
end
