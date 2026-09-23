# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module RunPage
      module_function

      def prepare!
        support = root_switch_support
        return unless support
        return if support > RunsController

        RunsController.include support
        RunsController.skip_recording_studio_root_resolution
      end

      def root_switch_support
        return unless defined?(RecordingStudio::RootSwitchable::ControllerSupport)

        RecordingStudio::RootSwitchable::ControllerSupport
      end
    end
  end
end
