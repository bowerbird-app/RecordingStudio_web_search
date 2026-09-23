# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    module StaffGate
      def authenticate_staff!
        method_name = staff_auth_method
        return send(method_name) if method_name && respond_to?(method_name, true)

        head :unauthorized
      end

      def authorize_staff!
        return if performed?
        return head(:forbidden) unless defined?(RecordingStudioAdmin)

        RecordingStudioAdmin::Authorization.authorize!(staff_context, recording: staff_recording)
      rescue RecordingStudioAdmin::AuthorizationFailed
        head :forbidden
      end

      def page_nav_anchor_url(default: nil)
        SearchesReturn.anchor(params[:anchor_url], default: default)
      end

      private

      def staff_auth_method
        return unless defined?(RecordingStudioAdmin)

        RecordingStudioAdmin.configuration.authentication_method
      end

      def staff_context
        RecordingStudioAdmin::Context.new(
          params: params.to_unsafe_h,
          current_actor: staff_actor,
          controller: self,
          routes: self,
          view_context: view_context
        )
      end

      def staff_actor
        method_name = RecordingStudioAdmin.configuration.current_actor_method
        send(method_name) if method_name && respond_to?(method_name, true)
      end

      def staff_recording
        resolver = RecordingStudioAdmin.configuration.access_recording_resolver
        resolver&.call(staff_context)
      end
    end
  end
end
