# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    # Rails I18n lookups for Web Search user-facing copy. Every call passes
    # `default:` English so a host locale without a fallback never shows
    # "translation missing".
    module Copy
      PREFIX = "recording_studio.web_search"

      module_function

      def t(key, **)
        I18n.t("#{PREFIX}.#{key}", **)
      end
    end
  end
end
