# frozen_string_literal: true

require "recording_studio_web_search/provider_catalog"

module RecordingStudio
  module WebSearch
    module Admin
      def self.register!
        return unless defined?(RecordingStudioAdmin)

        RecordingStudioAdmin.register_screen(ProvidersScreen)
        RecordingStudioAdmin.register_screen(SearchesScreen)
        RecordingStudioAdmin.register_widget(ProvidersWidget)
        RecordingStudioAdmin.register_widget(FailuresWidget)
        RecordingStudioAdmin.register_section(WebSearchSection)
      end

      class ProvidersScreen < RecordingStudioAdmin::Screen
        key "web_search_providers"
        icon :document_text
        title "Providers"
        subtitle "Who can answer a search."
        blast_radius :site
        query { |_context| ProviderCatalog.relation }

        table do
          column :name, title: "Provider"
          column :status, title: "Status"
          column :searches, title: "Searches"
          column :spent, title: "Spent"
          default_sort :name, direction: :asc
          paginate per_page: 25
        end
      end

      class SearchesScreen < RecordingStudioAdmin::Screen
        key "web_search_runs"
        icon :magnifying_glass
        title "Searches"
        subtitle "Every search that left this app."
        blast_radius :site
        query { |_context| SearchRun.order(created_at: :desc) }
        filter_presentation :inline
        filter :date_range, field: :created_at, default: :last_30_days
        filter :provider, options: -> { RecordingStudio::WebSearch.provider_names.map(&:to_s) }
        filter :status, options: %w[succeeded failed]

        summary do
          label "Spent"
          value { |context| SearchesScreen.total_spend(context.query_result.relation) }
          hide_change
        end

        chart do
          title "Spend"
          type :line
          series do |context|
            [{ name: "Spent", data: SearchesScreen.spend_series(context.query_result.relation) }]
          end
        end

        table do
          title "Log"
          filter :search, apply: lambda { |relation, value, _context|
            next relation if value.blank?

            quoted = "%#{ActiveRecord::Base.sanitize_sql_like(value)}%"
            relation.where("query ILIKE ?", quoted)
          }
          column :created_at, title: "When"
          column :provider, title: "Provider", value: lambda { |row, _context|
            ProviderCatalog.label_for(row.provider)
          }
          column :status, title: "Status", display: :badge, display_options: lambda { |row, _context, value|
            {
              text: row.outcome,
              size: :sm,
              style: value == "succeeded" ? :success : :danger
            }
          }
          column :query, title: "Query"
          column :result_count, title: "Results"
          column :estimated_cost_usd, title: "Spent", value: lambda { |row, _context|
            format("$%.3f", row.estimated_cost_usd.to_f)
          }
          default_sort :created_at, direction: :desc
          paginate per_page: 25
        end

        def self.total_spend(relation)
          SpendAmount.new(unordered(relation).sum(:estimated_cost_usd))
        end

        def self.spend_series(relation)
          DayPoints.from(unordered(relation).group(day_bucket).sum(:estimated_cost_usd))
        end

        def self.unordered(relation)
          relation.respond_to?(:except) ? relation.except(:order) : relation
        end

        def self.day_bucket
          Arel.sql("DATE(created_at)")
        end
      end

      ProvidersWidget = RecordingStudioAdmin::Widget.new("widgets.web_search.providers", blast_radius: :site) do
        type :list
        title "Providers"
        info "Brave is ready when the server has a key. This page never shows the key."
        list_options divider: true, hover: true
        items do |context|
          ProviderCatalog.rows.map do |row|
            {
              text: "#{row.name}. #{row.status}",
              href: context.admin_screen_path("web_search_providers")
            }
          end
        end
        link_to { |context| context.admin_screen_path("web_search_providers") }
      end

      FailuresWidget = RecordingStudioAdmin::Widget.new("widgets.web_search.failures", blast_radius: :site) do
        type :chart
        title "Failures"
        info "Searches that did not come back."
        chart_type :bar
        value do |context|
          FailureSeries.failed_relation(context).count
        end
        series do |context|
          [{ name: "Failures", data: FailureSeries.series_for(context) }]
        end
        chart_options({ height: 220 })
        link_to { |context| "#{context.admin_screen_path('web_search_runs')}?status=failed" }
      end

      class SpendAmount
        def initialize(amount)
          @amount = amount.to_f
        end

        def zero? = @amount.zero?
        def positive? = @amount.positive?
        def to_f = @amount
        def -(other) = @amount - other.to_f
        def to_s = format("$%.3f", @amount)
      end

      module DayPoints
        module_function

        def from(grouped)
          grouped.sort_by { |date, _amount| date.to_s }.map do |date, amount|
            { x: day_label(date), y: amount.to_f }
          end
        end

        def day_label(date)
          return date.strftime("%b %-d") if date.respond_to?(:strftime)

          date.to_s
        end
      end

      module FailureSeries
        module_function

        def failed_relation(context)
          SearchRun.where(status: "failed", created_at: time_range(context))
        end

        def series_for(context)
          grouped = failed_relation(context).group(Arel.sql("DATE(created_at)")).count
          DayPoints.from(grouped)
        end

        def time_range(context)
          return context.widget_time_range if context.widget_time_range

          period = context.period_for(preset_key: :last_30_days)
          period.start_date.beginning_of_day..period.end_date.end_of_day
        end
      end

      class WebSearchSection < RecordingStudioAdmin::Section
        key "web_search"
        icon :magnifying_glass
        title "Web search"
        subtitle "See who searches, what failed, and what it cost."
        blast_radius :site

        link :providers,
             text: "View providers",
             url: ->(context) { context.admin_screen_path("web_search_providers") },
             style: :secondary
        link :searches,
             text: "View searches",
             url: ->(context) { context.admin_screen_path("web_search_runs") },
             style: :secondary

        widget "widgets.web_search.providers"
        widget "widgets.web_search.failures", params: { preset_key: :last_30_days }
      end
    end
  end
end
