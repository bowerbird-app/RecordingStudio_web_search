# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module Api
      class Search
        def self.call(context)
          context.access_grant.authorize!(recording: context.root_recording, role: VIEW_ROLE)

          RecordingStudio::WebSearch.search(
            context.params.fetch(:query),
            **search_options(context.params),
            attribution: attribution_from(context)
          ).to_h
        end

        def self.search_options(params)
          AiTool::OPTION_KEYS.each_with_object({}) do |key, options|
            options[key] = params[key] if params.key?(key)
          end
        end

        def self.attribution_from(context)
          return context.attribution if context.respond_to?(:attribution)

          context
        end
        private_class_method :search_options, :attribution_from
      end
    end
  end
end
