# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class RunsController < ApplicationController
      include StaffGate

      helper RecordingStudio::LayoutHelper if defined?(RecordingStudio::LayoutHelper)
      helper_method :page_nav_anchor_url, :result_item_options

      layout "recording_studio/default_layout"

      before_action :authenticate_staff!
      before_action :authorize_staff!

      def show
        @run = SearchRun.find(params[:id])
        @pages = ResultSnapshot.pages(@run.results)
        @back_url = SearchesReturn.path(params[:anchor_url])
        @subtitle = run_subtitle
        @empty_message = empty_message
      end

      private

      def run_subtitle
        parts = [
          ProviderCatalog.label_for(@run.provider),
          @run.created_at&.strftime("%b %-d, %Y"),
          format("$%.3f", @run.estimated_cost_usd.to_f)
        ]
        parts.compact.join(" · ")
      end

      def empty_message
        return "Nothing came back." unless @run.status == "succeeded"
        return "Nothing turned up." if @run.result_count.to_i.zero?

        "These pages were not kept."
      end

      def result_item_options(page)
        return { hover: false } if page["url"].blank?

        {
          href: page["url"],
          hover: true,
          link_arguments: { target: "_blank", rel: "noopener noreferrer" }
        }
      end
    end
  end
end
