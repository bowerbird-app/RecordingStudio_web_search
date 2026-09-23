# frozen_string_literal: true

require "net/http"
require "uri"

module RecordingStudio
  module WebSearch
    module Providers
      class BraveRequest
        HOST = "api.search.brave.com"
        PATH = "/res/v1/web/search"
        FRESHNESS = { day: "pd", week: "pw", month: "pm", year: "py" }.freeze

        def initialize(query, token)
          @query = query
          @token = token
        end

        def uri
          uri = URI::HTTPS.build(host: HOST, path: PATH)
          uri.query = URI.encode_www_form(params)
          uri
        end

        def http_request
          request = Net::HTTP::Get.new(uri)
          request["X-Subscription-Token"] = @token
          request["Accept"] = "application/json"
          request
        end

        private

        def params
          optional_params.merge(
            q: @query.text,
            count: @query.count,
            offset: @query.page,
            safesearch: @query.safe_search.to_s
          )
        end

        def optional_params
          params = { text_decorations: false }
          params[:country] = @query.country if @query.country
          params[:search_lang] = @query.language if @query.language
          params[:freshness] = freshness if @query.freshness
          params[:extra_snippets] = true if @query.extra_snippets
          params
        end

        def freshness
          FRESHNESS.fetch(@query.freshness, @query.freshness.to_s)
        end
      end
    end
  end
end
