# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class ProviderCatalog
      Row = Data.define(:name, :status, :searches, :spent)

      class Relation
        def initialize(rows, limit: nil, offset: 0)
          @rows = rows
          @limit = limit
          @offset = offset
        end

        def where(filters)
          selected = @rows
          filters.each do |key, value|
            selected = selected.select { |row| row.public_send(key).to_s == value.to_s }
          end
          self.class.new(selected)
        end

        def order(ordering)
          key, direction = ordering.first
          sorted = @rows.sort_by { |row| sort_value(row.public_send(key)) }
          sorted.reverse! if direction.to_s == "desc"
          self.class.new(sorted, limit: @limit, offset: @offset)
        end

        def limit(value)
          self.class.new(@rows, limit: value, offset: @offset)
        end

        def offset(value)
          self.class.new(@rows, limit: @limit, offset: value)
        end

        def count
          @rows.size
        end

        def to_a
          sliced = @rows.drop(@offset)
          @limit ? sliced.first(@limit) : sliced
        end

        private

        def sort_value(value)
          value.is_a?(Numeric) ? [0, value] : [1, value.to_s]
        end
      end

      def self.relation
        Relation.new(rows)
      end

      def self.rows
        counts = grouped_count
        spend = grouped_spend
        RecordingStudio::WebSearch.provider_names.map { |name| row_for(name, counts, spend) }
      end

      def self.row_for(name, counts, spend)
        key = name.to_s
        Row.new(
          name: label_for(key),
          status: key_status(name),
          searches: counts.fetch(key, 0),
          spent: format("$%.3f", spend.fetch(key, 0).to_f)
        )
      end

      def self.label_for(name)
        name.to_s.tr("_", " ").split.map(&:capitalize).join(" ")
      end

      def self.key_status(name)
        return "Ready" unless name.to_sym == :brave

        if RecordingStudio::WebSearch.configuration.brave_api_key_configured?
          "Ready"
        else
          "Needs a key"
        end
      end

      def self.grouped_count
        model = search_runs
        return {} unless model&.table_ready?

        model.group(:provider).count
      rescue ActiveRecord::StatementInvalid
        {}
      end

      def self.grouped_spend
        model = search_runs
        return {} unless model&.table_ready?

        model.group(:provider).sum(:estimated_cost_usd)
      rescue ActiveRecord::StatementInvalid
        {}
      end

      def self.search_runs
        "RecordingStudio::WebSearch::SearchRun".safe_constantize
      end
    end
  end
end
