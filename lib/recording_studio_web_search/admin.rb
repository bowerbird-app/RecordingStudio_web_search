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
        # Flatpack's "Last 4 weeks" preset is 27 days back through today.
        filter :date_range, field: :created_at, default: :last_27_days
        filter :provider, options: -> { RecordingStudio::WebSearch.provider_names.map(&:to_s) }
        filter :status, options: %w[succeeded failed]

        summary do
          label "Searches"
          value { |context| SearchesScreen.search_count(context.query_result.relation) }
          hide_change
          hide_period
        end

        chart do
          title "Searches"
          type :line
          series do |context|
            [{ name: "Searches", data: SearchesScreen.search_series(context) }]
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

        def self.search_count(relation)
          unordered(relation).count
        end

        def self.search_series(context)
          relation = context.query_result.relation
          grouped = unordered(relation).group(day_bucket).count
          DayPoints.from(grouped, range: context.filter_value(:date_range))
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
              href: RecordingStudio::WebSearch::Admin.screen_href(context, "web_search_providers")
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
        link_to { |context| RecordingStudio::WebSearch::Admin.screen_href(context, "web_search_runs", "status=failed") }
      end

      module DayPoints
        module_function

        def from(grouped, range: nil)
          counts = index_counts(grouped)
          dates_for(counts, range).map do |date|
            { x: day_label(date), y: counts.fetch(date, 0).to_f }
          end
        end

        def index_counts(grouped)
          grouped.transform_keys { |date| coerce_date(date) }
        end

        def dates_for(counts, range)
          day_span(range) || counts.keys.sort
        end

        def day_span(range)
          return unless range.respond_to?(:start_date) && range.start_date && range.end_date

          (range.start_date.to_date..range.end_date.to_date).to_a
        end

        def coerce_date(date)
          date.respond_to?(:to_date) ? date.to_date : Date.iso8601(date.to_s)
        end

        def day_label(date)
          return date.strftime("%b %-d") if date.respond_to?(:strftime)

          date.to_s
        end
      end

      def self.screen_href(context, key, extra = nil)
        path = context.admin_screen_path(key)
        path = "#{path}?#{extra}" if extra
        anchor = anchor_from(context)
        return path if anchor.blank?

        join_anchor(path, anchor)
      end

      def self.anchor_from(context)
        params = context.params
        params[:anchor_url].presence || params["anchor_url"].presence
      end

      def self.join_anchor(path, anchor)
        uri = URI.parse(path)
        query = Rack::Utils.parse_nested_query(uri.query)
        query["anchor_url"] = anchor
        uri.query = query.to_query
        uri.to_s
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
