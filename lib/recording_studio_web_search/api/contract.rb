# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module Api
      OPENAPI = {
        title: "Web search",
        summary: "Search the public web",
        description: "Searches the public web and brings back titles, links, and short descriptions.",
        tags: ["Web search"],
        parameters: [
          {
            name: "query",
            in: "query",
            required: true,
            description: "Words to search for.",
            schema: { type: "string" }
          },
          {
            name: "country",
            in: "query",
            required: false,
            description: "Two-letter country code, such as US.",
            schema: { type: "string" }
          },
          {
            name: "language",
            in: "query",
            required: false,
            description: "Language code, such as en.",
            schema: { type: "string" }
          },
          {
            name: "freshness",
            in: "query",
            required: false,
            description: "How new the pages should be: day, week, month, year, or 2026-01-01to2026-01-31.",
            schema: { type: "string" }
          },
          {
            name: "count",
            in: "query",
            required: false,
            description: "How many pages to return, from 1 to 20.",
            schema: { type: "integer" }
          }
        ]
      }.freeze

      INPUT_CONTRACT = {
        reject_unknown: false,
        fields: {
          query: {
            type: :string,
            required: true,
            allow_blank: false,
            description: "Words to search for."
          },
          country: {
            type: :string,
            required: false,
            description: "Two-letter country code, such as US."
          },
          language: {
            type: :string,
            required: false,
            description: "Language code, such as en."
          },
          freshness: {
            type: :string,
            required: false,
            description: "How new the pages should be: day, week, month, year, or 2026-01-01to2026-01-31."
          },
          count: {
            type: :integer,
            required: false,
            description: "How many pages to return, from 1 to 20."
          }
        }
      }.freeze
    end
  end
end
