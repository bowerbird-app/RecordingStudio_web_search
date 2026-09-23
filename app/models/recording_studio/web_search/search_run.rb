# frozen_string_literal: true

module RecordingStudio
  module WebSearch
    class SearchRun < ApplicationRecord
      self.table_name = "recording_studio_web_search_runs"

      def self.write(attributes)
        return unless table_ready?

        create!(attributes)
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError, ActiveRecord::StatementInvalid
        nil
      end

      def self.table_ready?
        connection.table_exists?(table_name)
      rescue ActiveRecord::ConnectionNotEstablished, ActiveRecord::NoDatabaseError
        false
      end
    end
  end
end
