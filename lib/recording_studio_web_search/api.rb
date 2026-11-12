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
          return unless defined?(::RecordingStudioApi)

          RecordingStudioApi.configuration.each_api { |api| register_on(api) }
        end

        private

        def register_on(api)
          return if already_registered?(api)

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

        def already_registered?(api)
          existing = RecordingStudioApi.registered_endpoint(NAME, api: api.name)
          return false unless existing
          return true if existing.handler == Search

          raise RecordingStudioApi::ConfigurationError, "API endpoint #{NAME} is already registered"
        end
      end
    end
  end
end
