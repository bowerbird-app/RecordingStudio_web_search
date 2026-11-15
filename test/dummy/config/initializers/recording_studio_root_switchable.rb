# frozen_string_literal: true

RecordingStudioRootSwitchable.configure do |config|
  config.current_actor_resolver = lambda do |controller:|
    Current.actor || controller.current_user
  end

  # Mounted switcher pages use the same shell as signed-in dummy pages.
  # Core 6 accepts a layout name. A symbol method name is no longer a layout setting.
  config.layout = "recording_studio/default_layout"

  config.after_switch_redirect = lambda do |controller:, return_to:, **|
    candidate_path = return_to.presence
    candidate_path = controller.main_app.root_path if candidate_path.blank?

    if internal_route?(candidate_path)
      candidate_path
    else
      controller.main_app.root_path
    end
  end

  config.scope :all_workspaces do |scope|
    scope.label = "All workspaces"
    scope.description = "Every workspace root in the dummy app."
    scope.available_roots = lambda do |**|
      Workspace.order(:name).filter_map do |workspace|
        RecordingStudio.root_recording_for(workspace)
      end
    end
    # Root Switchable 0.16 refuses the switch page unless the actor can view
    # the current root. Listing every workspace made a seeded root the current
    # one for a user who does not own it.
    scope.access_check = lambda do |actor:, recording:, **|
      actor.present? &&
        RecordingStudioAccessible.authorized?(actor: actor, recording: recording, role: :view)
    end

    scope.default_root = lambda do |roots:, **|
      roots.first
    end
  end
end

def internal_route?(path)
  routes = [
    Rails.application.routes,
    RecordingStudioRootSwitchable::Engine.routes
  ]

  routes.any? do |route_set|
    route_set.recognize_path(path, method: :get)
    true
  rescue StandardError
    false
  end
end
