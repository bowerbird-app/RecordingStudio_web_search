# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.5.0] - 2026-10-12

### Added

* Rails I18n for user-facing Admin DSL chrome outside views (`lib/recording_studio_web_search/admin.rb`):
  section title/subtitle, screen titles, widget titles/info, section link text,
  summary label, and chart titles/series names. Keys live under
  `recording_studio.web_search.admin` with English `default:` on every lookup.
* `RecordingStudio::WebSearch::Copy` helper for those lookups.
* Boot-order host override fixture under
  `test/dummy/config/locales/recording_studio_web_search_host.en.yml` for the
  rarely shown failures-widget info key, plus a widened
  `lib/**/*.rb` regression guard that refutes `i18n.load_path` /
  `I18n.load_path`.

### Changed

* Version `0.4.0` → `0.5.0`.
* Every existing run-show `t(...)` lookup now passes an English `default:` so a
  host locale without a fallback never shows "translation missing". English
  output stays byte-identical to `0.4.0`.

### Upgrade notes

- No migration or host code change is required for English.
- Hosts that override `recording_studio.web_search` keys continue to win. New
  keys cover Admin DSL chrome; Admin table column headers, table title
  (`Log`), screen subtitles, and cell values remain English literals.
- See [UPGRADING.md](UPGRADING.md#050).

## [0.4.0] - 2026-10-09

### Added

* English Rails I18n keys for static interface copy on the search run show page
  (`config/locales/en.yml` under `recording_studio.web_search`)

### Changed

* Run show PageNav/button label and empty-state messages resolve through `t(...)`
  (English output unchanged)

### Upgrade notes

- No migration or host code change is required for English.
- To translate or override the defaults, add keys under
  `recording_studio.web_search.runs` in the host's locale files.
- See [UPGRADING.md](UPGRADING.md#040).

## [0.3.0] - 2026-09-30


### Added

- Optional host usage metering with `usage_handler` and `usage_key_resolver`
- Optional `attribution:` keyword on `RecordingStudio::WebSearch.search`

### Changed

- When a charge exists, `recording_studio_web_search_runs.id` is the attempt uuid

## [0.2.0] - 2026-09-23

### Added

- A `web_search` custom tool for Recording Studio AI, registered when that gem is loaded

## [0.1.0] - 2026-09-22

### Added

- Provider-neutral `RecordingStudio::WebSearch.search` with Brave as the first provider
- Query options, value objects, cost, and `search.recording_studio_web_search` instrumentation
- Dummy host search page behind Devise
- Optional admin section for providers, search runs, spend, and failures when Recording Studio Admin is installed
- Searches chart of each day in the last 4 weeks, and a provider filter on the dummy search form
- Search log keeps a page snapshot, and the results count opens that run

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/releases/tag/v0.1.0
