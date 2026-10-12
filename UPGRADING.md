# Upgrading

## 0.5.0

This is a non-breaking upgrade. Rendered English interface text stays
byte-identical to `0.4.0`.

### What Changed

- Admin DSL chrome in `lib/recording_studio_web_search/admin.rb` (section
  title/subtitle, screen titles, widget titles/info, link text, summary label,
  chart titles/series names) resolves through
  `RecordingStudio::WebSearch::Copy.t(..., default: …)`.
- Every run-show `t(...)` lookup now passes an English `default:`.
- Boot-order host override under
  `test/dummy/config/locales/recording_studio_web_search_host.en.yml` covers the
  rarely shown failures-widget info key.

Keys added (under `recording_studio.web_search`):

| Key | English |
| --- | --- |
| `admin.section.title` | Web search |
| `admin.section.subtitle` | See who searches, what failed, and what it cost. |
| `admin.links.view_providers` | View providers |
| `admin.links.view_searches` | View searches |
| `admin.screens.providers.title` | Providers |
| `admin.screens.searches.title` | Searches |
| `admin.summary.searches` | Searches |
| `admin.chart.searches_title` | Searches |
| `admin.chart.searches_series` | Searches |
| `admin.chart.failures_series` | Failures |
| `admin.widgets.providers.title` | Providers |
| `admin.widgets.providers.info` | Brave is ready when the server has a key. This page never shows the key. |
| `admin.widgets.failures.title` | Failures |
| `admin.widgets.failures.info` | Searches that did not come back. |

Left untranslated on purpose: Admin screen subtitles and table title (`Log`)
(Admin search/resolvers read those fields raw), Admin column headers and cell
values (including `None`, stored run outcomes, provider Ready/Needs a key),
AI tool `DEFINITION` strings, RunLog/Usage outcome constants, exception
messages, generator CLI text, icon/style tokens, and dummy app views.

### Upgrade Steps

No migration is required. English hosts need no change. To override or add
another language, set the keys above in the host's `config/locales`.

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
