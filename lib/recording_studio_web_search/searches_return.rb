# frozen_string_literal: true

require "rack/utils"

module RecordingStudio
  module WebSearch
    module SearchesReturn
      module_function

      def path(anchor)
        base = "#{mount}/screens/web_search_runs"
        safe = anchor_url(anchor)
        return base if safe.blank?

        "#{base}?#{Rack::Utils.build_query(anchor_url: safe)}"
      end

      def anchor(value, default: nil)
        anchor_url(value).presence || default
      end

      def mount
        return "/admin" unless defined?(RecordingStudioAdmin)

        RecordingStudioAdmin.configuration.default_mount_path.presence || "/admin"
      end

      def anchor_url(value)
        return if value.blank? || !defined?(RecordingStudioAdmin)

        url = RecordingStudioAdmin::UrlSafety.safe_href(value, allow_external: true)
        return if url.blank? || url == "#"

        url
      end
    end
  end
end
