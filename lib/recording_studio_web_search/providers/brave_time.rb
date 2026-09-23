# frozen_string_literal: true

require "date"
require "time"

module RecordingStudio
  module WebSearch
    module Providers
      module BraveTime
        module_function

        def published_at(value)
          return if value.to_s.strip.empty?

          Time.iso8601(value)
        rescue ArgumentError
          date_only(value)
        end

        def date_only(value)
          Date.iso8601(value).to_time
        rescue ArgumentError, TypeError
          nil
        end

        def retry_after(value)
          return if value.to_s.strip.empty?

          Integer(value)
        rescue ArgumentError, TypeError
          retry_httpdate(value)
        end

        def retry_httpdate(value)
          (Time.httpdate(value) - Time.now).to_i
        rescue ArgumentError
          nil
        end
      end
    end
  end
end
