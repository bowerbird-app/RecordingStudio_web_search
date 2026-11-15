# frozen_string_literal: true

RecordingStudioAccessible.configure do |config|
  config.access_actor_types = [ "User" ]
  config.access_actor_types += [ "RecordingStudioApi::ApiClient" ]

  # Site-wide admin screens (blast_radius :site) resolve only when this kept
  # root is the current access recording and the actor holds a role on it.
  config.admin_root_resolver = lambda do |**|
    admin_root = AdminRoot.find_by(name: "Admin")
    next unless admin_root

    RecordingStudio.root_recording_for(admin_root)
  end
end
