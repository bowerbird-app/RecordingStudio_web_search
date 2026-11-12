# frozen_string_literal: true

require_relative "api/contract"
require_relative "api/search"

module RecordingStudio
  module WebSearch
    # Registers one GET endpoint when Recording Studio API is loaded.
    # MCP advertises registered endpoints automatically. This gem adds no MCP tools.
    module Api
      NAME = "web_search.search"
      PATH = "web_search"
      VIEW_ROLE = :view

      class << self
        def register!
          return unless available?

          RecordingStudioApi.configuration.each_api { |api| register_on(api) }
          true
        end

        def available?
          defined?(RecordingStudioApi) &&
            RecordingStudioApi.respond_to?(:register_endpoint) &&
            RecordingStudioApi.respond_to?(:registered_endpoint) &&
            RecordingStudioApi.respond_to?(:configuration)
        end

        private

        def register_on(api)
          return if RecordingStudioApi.registered_endpoint(NAME, api: api.name)

          RecordingStudioApi.register_endpoint(
            NAME,
            api: api.name,
            http_verb: :get,
            path: PATH,
            handler: Search,
            openapi: OPENAPI,
            input_contract: INPUT_CONTRACT
          )
        end
      end
    end
  end
end
