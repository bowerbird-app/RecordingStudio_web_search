# Upgrading

## 0.4.0

This is a non-breaking upgrade. Rendered English interface text on the search run
show page is unchanged.

### What Changed

- Static copy in the gem's own run show view and empty-state messages uses Rails
  I18n keys under `recording_studio.web_search.runs`.
- The gem ships English only in `config/locales/en.yml` (Rails engines load that
  path by default). There is no dependency on
  `recording_studio_internationalization`.

Keys added:

| Key | English |
| --- | --- |
| `recording_studio.web_search.runs.searches` | Searches |
| `recording_studio.web_search.runs.empty.nothing_came_back` | Nothing came back. |
| `recording_studio.web_search.runs.empty.nothing_turned_up` | Nothing turned up. |
| `recording_studio.web_search.runs.empty.pages_not_kept` | These pages were not kept. |

Left untranslated on purpose: admin screen/widget copy in `lib/` (out of scope for
this pass), AI tool descriptions, provider status and run outcome strings stored
on the log, search result titles/URLs/domains/descriptions, subtitle parts built
from provider/date/cost, icon and style tokens, and dummy app views.

This gem did not previously ship a top-level `recording_studio_web_search.*`
locale namespace for interface text. New strings use the nested
`recording_studio.web_search` namespace.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the keys above in the host's `config/locales`.

## 0.3.0


No migration.

`usage_handler` and `usage_key_resolver` are new settings on `RecordingStudio::WebSearch::Configuration`. Both default to nil. Leave them nil and `RecordingStudio::WebSearch.search` matches 0.2.0.

Set both procs when a search should spend credits. `RecordingStudio::WebSearch.configure` checks them after the block. Engine boot checks them after the `on_configuration` hook. A handler without a callable resolver raises `RecordingStudio::WebSearch::Usage::ConfigurationError`.

Pass `attribution:` beside `provider:` when the host should bill that call. It is not a query option. The README section "Charge a search" shows a host handler.

A handler exception comes back as the same object. The run outcome is "Usage declined" when the handler refuses the charge, and the run id is the attempt uuid when a charge exists. `Usage::ConfigurationError` keeps the outcome "Check usage". No new columns were added.
