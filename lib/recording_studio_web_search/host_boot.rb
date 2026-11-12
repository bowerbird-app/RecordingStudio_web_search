# frozen_string_literal: true

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

        require "recording_studio_web_search/api"
        Api.register!
      end

      def self.register_admin!
        return unless defined?(RecordingStudioAdmin)

        require "recording_studio_web_search/admin"
        Admin.register!
      end
    end
  end
end
