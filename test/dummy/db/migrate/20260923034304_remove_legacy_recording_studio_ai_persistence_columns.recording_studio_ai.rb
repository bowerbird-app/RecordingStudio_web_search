# frozen_string_literal: true

# This migration comes from recording_studio_ai (originally 20260813120000)
class RemoveLegacyRecordingStudioAIPersistenceColumns < ActiveRecord::Migration[8.1]
  def up
    drop_present :recording_studio_ai_runs,
                 :initiator_snapshot,
                 :executor_snapshot,
                 :impersonator_snapshot,
                 :input_digest,
                 :output_digest
    drop_present :recording_studio_ai_custom_tool_invocations,
                 :arguments_digest,
                 :arguments_summary,
                 :result_digest
    drop_present :recording_studio_ai_batches,
                 :initiator_snapshot,
                 :executor_snapshot,
                 :impersonator_snapshot
  end

  def down; end

  private

  # The published create migration already omits these columns on a fresh install.
  def drop_present(table, *columns)
    present = columns.select { |column| column_exists?(table, column) }
    remove_columns(table, *present) if present.any?
  end
end