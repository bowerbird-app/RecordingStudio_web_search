# frozen_string_literal: true

require "recording_studio_web_search/api"

module RecordingStudio
  module WebSearch
    module HostBoot
      def self.prepare!
        AiTool.register!
        register_api!
        register_admin!
        RunPage.prepare!
      end

      def self.register_api!
        return unless defined?(RecordingStudioApi)

        Api.register!
      end

      def self.register_admin!
        return unless defined?(RecordingStudioAdmin)
        # Url-safety and staff-gate stubs define the module without the registry.
        # Screen subclasses load only when Admin can actually register them.
        return unless RecordingStudioAdmin.respond_to?(:register_screen)

        require "recording_studio_web_search/admin"
        Admin.register!
      end
    end
  end
end
