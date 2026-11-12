# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module Api
      class Search
        OPTION_KEYS = %i[country language freshness count].freeze

        def self.call(context)
          context.access_grant.authorize!(recording: context.root_recording, role: VIEW_ROLE)

          RecordingStudio::WebSearch.search(
            context.params.fetch(:query),
            **search_options(context.params),
            attribution: context
          ).to_h
        rescue InvalidQueryError => e
          raise RecordingStudioApi::InvalidActionInputError, e.message
        end

        def self.search_options(params)
          OPTION_KEYS.each_with_object({}) do |key, options|
            options[key] = params[key] if params.key?(key)
          end
        end
        private_class_method :search_options
      end
    end
  end
end
