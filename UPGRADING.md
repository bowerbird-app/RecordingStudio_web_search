# Upgrading

## 0.3.0

No migration.

`usage_handler` and `usage_key_resolver` are new settings on `RecordingStudio::WebSearch::Configuration`. Both default to nil. Leave them nil and `RecordingStudio::WebSearch.search` matches 0.2.0.

Set both procs when a search should spend credits. `RecordingStudio::WebSearch.configure` checks them after the block. Engine boot checks them after the `on_configuration` hook. A handler without a callable resolver raises `RecordingStudio::WebSearch::Usage::ConfigurationError`.

Pass `attribution:` beside `provider:` when the host should bill that call. It is not a query option. The README section "Charge a search" shows a host handler.

A handler exception comes back as the same object. The run outcome is "Usage declined" when the handler refuses the charge, and the run id is the attempt uuid when a charge exists. `Usage::ConfigurationError` keeps the outcome "Check usage". No new columns were added.
