# frozen_string_literal: true

require "cgi"
require "json"
require "uri"

module RecordingStudio
  module WebSearch
    module Providers
      class BraveMapper
        METADATA_KEYS = %i[age].freeze

        def initialize(cost)
          @cost = cost
        end

        def map(query, response)
          status = response.code.to_i
          return parse_success(query, response, status) if status.between?(200, 299)

          raise_status_error(response, status)
        end

        private

        def raise_status_error(response, status)
          case status
          when 401, 403 then authentication_error(status)
          when 429 then rate_limit_error(response)
          when 408
            raise TimeoutError.new("The search request timed out", status: 408)
          else
            raise ProviderError.new("The search provider returned an error", status: status)
          end
        end

        def authentication_error(status)
          raise AuthenticationError.new("The search provider rejected the credentials", status: status)
        end

        def rate_limit_error(response)
          raise RateLimitError.new(
            "The search provider rate-limited the request",
            status: 429,
            retry_after: BraveTime.retry_after(response["Retry-After"])
          )
        end

        def parse_success(query, response, status)
          body = JSON.parse(response.body)
          web = body["web"]
          raise invalid_response(status) unless web.is_a?(Hash)

          build_response(query, body, web)
        rescue JSON::ParserError
          raise invalid_response(status)
        end

        def build_response(query, body, web)
          results = Array(web["results"]).map { |item| map_result(item) }
          SearchResponse.new(
            query: query.text,
            provider: :brave,
            results: results,
            metadata: response_metadata(query, results),
            more_results: body.dig("query", "more_results_available") == true
          )
        end

        def invalid_response(status)
          InvalidResponseError.new("The search provider returned an invalid response", status: status)
        end

        def response_metadata(query, results)
          {
            estimated_cost_usd: @cost,
            result_count: results.size,
            page: query.page,
            count: query.count
          }
        end

        def map_result(item)
          item = item.to_h
          url = item["url"].to_s
          description = plain_text(item["description"])
          SearchResult.new(**result_fields(item, url, description))
        end

        def result_fields(item, url, description)
          {
            title: plain_text(item["title"]).to_s, url: url, description: description,
            snippets: map_snippets(item["extra_snippets"], description),
            published_at: BraveTime.published_at(item["page_age"]),
            domain: domain_from(url), metadata: result_metadata(item)
          }
        end

        def map_snippets(extra, description)
          return [] unless extra.is_a?(Array)

          extra.filter_map { |snippet| plain_text(snippet) }.reject { |snippet| snippet == description }
        end

        def result_metadata(item)
          METADATA_KEYS.each_with_object({}) do |key, metadata|
            value = item[key.to_s]
            metadata[key] = value unless value.nil?
          end
        end

        def domain_from(url)
          URI.parse(url).host.to_s.downcase.delete_prefix("www.")
        rescue URI::InvalidURIError
          ""
        end

        def plain_text(value)
          return if value.nil?

          text = CGI.unescapeHTML(value.to_s).gsub(/<[^>]*>/, "").strip
          text.empty? ? nil : text
        end
      end
    end
  end
end
