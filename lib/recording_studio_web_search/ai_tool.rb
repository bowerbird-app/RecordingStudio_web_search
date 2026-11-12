# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    # Registers the public search API as a Recording Studio AI custom tool.
    # This gem does not depend on recording_studio_ai. Registration runs only
    # when that gem is already loaded.
    module AiTool
      KEY = :web_search
      VERSION = 1
      OPTION_KEYS = %i[country language freshness count].freeze

      DEFINITION = {
        key: KEY,
        version: VERSION,
        name: "Web search",
        description: "Searches the public web and brings back titles, links, and short descriptions.",
        use_when: "The question needs pages from the public web.",
        do_not_use_when: "The answer is already here, or it is not about the public web.",
        parameters: [
          {
            name: :query,
            type: :string,
            required: true,
            description: "Words to search for."
          },
          {
            name: :country,
            type: :string,
            required: false,
            description: "Two-letter country code, such as US."
          },
          {
            name: :language,
            type: :string,
            required: false,
            description: "Language code, such as en."
          },
          {
            name: :freshness,
            type: :string,
            required: false,
            description: "How new the pages should be: day, week, month, year, or 2026-01-01to2026-01-31."
          },
          {
            name: :count,
            type: :integer,
            required: false,
            description: "How many pages to return, from 1 to 20."
          }
        ],
        returns: "The search response: query, provider, results, metadata, and whether more pages exist.",
        cost: :low,
        latency: :slow,
        read_only: true,
        destructive: false,
        requires_confirmation: false,
        idempotent: true,
        executor_label: "RecordingStudio::WebSearch.search",
        executor: ->(arguments, context) { execute(arguments, context).to_h }
      }.freeze

      def self.register!
        return unless defined?(::RecordingStudioAI)

        ::RecordingStudioAI.tools.register(**DEFINITION, override: true)
      end

      def self.execute(arguments, context = nil)
        authorize!(context)
        RecordingStudio::WebSearch.search(
          arguments.fetch("query"),
          **search_options(arguments),
          attribution: attribution_from(context)
        )
      end

      def self.authorize!(context)
        recording = context.root_recording if context.respond_to?(:root_recording)
        grant = context.access_grant if context.respond_to?(:access_grant)
        if grant.respond_to?(:authorize!)
          grant.authorize!(recording: recording, role: :view)
          return
        end

        actor = context.initiator if context.respond_to?(:initiator)
        return if defined?(::RecordingStudioAccessible) &&
                  ::RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)

        raise "API access grant is not authorized for this capability"
      end
      private_class_method :authorize!

      def self.attribution_from(context)
        return context.attribution if context.respond_to?(:attribution)

        context
      end
      private_class_method :attribution_from

      def self.search_options(arguments)
        OPTION_KEYS.each_with_object({}) do |key, options|
          name = key.to_s
          options[key] = arguments[name] if arguments.key?(name)
        end
      end
    end
  end
end
