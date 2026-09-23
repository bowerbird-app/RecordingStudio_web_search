# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    SearchResult = Data.define(:title, :url, :description, :snippets, :published_at, :domain, :metadata) do
      def to_h
        {
          "title" => title,
          "url" => url,
          "description" => description,
          "snippets" => snippets,
          "published_at" => published_at&.iso8601,
          "domain" => domain,
          "metadata" => stringify_keys(metadata)
        }
      end

      private

      def stringify_keys(value)
        value.to_h.transform_keys(&:to_s)
      end
    end
  end
end
