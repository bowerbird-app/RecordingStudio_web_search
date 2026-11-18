# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.1] - 2026-11-18

### Changed

* Development pins move to Recording Studio `v7.7.1` and Flatpack `v0.1.378`. The gemspec still accepts `recording_studio` `>= 7.0`, `< 8.0` and `flat_pack` `>= 0.1.341`.
* Dummy pins move to Accessible `v0.54.0`, Admin `v2.19.0`, AI `v0.25.0`, API `v1.15.0`, Icons `v0.4.1`, Moveable `v6.0.1`, Metrics `v0.9.1`, Logs `v0.8.1`, Trashable `v1.2.0`, and Cache `v0.7.0`. Root Switchable stays `v0.16.0`.
* The dummy adds a minimal `config/recording_studio_api.yml` so API 1.12+ can boot, and copies API 1.15's owner columns onto API clients. Recording Studio 7.4, 7.5, and 7.7 root migrations stay out of the dummy.

### Upgrade notes

- Install Recording Studio 7.7.1 and Flatpack `v0.1.378` from GitHub. Hosts that mount API 1.15 need Accessible 0.50 or newer and a `config/recording_studio_api.yml`.
- This gem ships no migrations. Hosts that move to Recording Studio 7.7 must run the Recording Studio 7.4, 7.5, and 7.7 root migrations. Only this repo's dummy app leaves them out.
- See [UPGRADING.md](UPGRADING.md#091).

## [0.9.0] - 2026-11-15

### Changed

* Require `recording_studio` `>= 7.0`, `< 8.0`. Development pins Recording Studio `v7.0.0` and Flatpack `v0.1.376`.
* Dummy pins move to the core-7 addon tags that this app already mounts: Accessible `v0.44.0`, Admin `v2.16.0`, AI `v0.22.0`, API `v0.24.0`, Icons `v0.2.1`, Moveable `v5.0.0`, Metrics `v0.9.0`, Logs `v0.8.0`, Trashable `v0.17.0`, and Cache `v0.6.3`.
* Root Switchable `v0.11.5` requires `recording_studio` `< 7` and Accessible `~> 0.18`, so it cannot resolve next to core 7. The dummy keeps the gem and pins `v0.16.0`, the published core-7 tag.
* Dummy roots are created with `RecordingStudio.create_root_recording!(recordable, actor:)`. `root_recording_for` stays find-only.
* The dummy `authorize_write` allows a present actor, including a root create where `root_recording` is nil.
* The dummy copies core's `recording_studio_events.root_recording_id` migration. Seeds look up children with `Recording.kept`. Admin uses `access_recording_resolver` and ignores the switched product root. Accessible `admin_root_resolver` points at that admin root so site-wide screens resolve. Seeds and the switcher grant the creating actor owner access on new roots. The all-workspaces scope lists roots that actor can view.
* Dummy pins Puma `8.1.0` and `msgpack` `>= 1.8.7` so Bundler Audit passes.
* Flatpack `0.1.376` renders `FlatPack::Text` weight as `data-fp-weight` instead of a `font-semibold` class. The run page still passes `weight: :semibold`.

### Upgrade notes

- Install Recording Studio 7.0 or newer, and below 8. Flatpack stays `>= 0.1.341` in the gemspec. This repo pins `v0.1.376`.
- Call sites that created a root through `root_recording_for` call `create_root_recording!(recordable, actor:)`. Lookup call sites keep `root_recording_for` and handle `nil`.
- Set `config.authorize_write`. Root creation calls it with `recording`, `root_recording`, and `parent_recording` all nil.
- Copy Recording Studio's events `root_recording_id` migration into the host and migrate. This gem ships no migration of its own.
- Trashable 0.17 removed `kept_sql`. Use `Recording.kept`.
- Admin 2.16 dropped `site_admin_recording_resolver`. Use `access_recording_resolver`.
- See [UPGRADING.md](UPGRADING.md#090).

## [0.8.0] - 2026-11-12

### Added

* A `web_search.search` Recording Studio API endpoint, registered when that gem is loaded. The handler authorizes the grant on the request root at `:view` and calls `RecordingStudio::WebSearch.search` with the request context as `attribution:`. Invalid queries map to `RecordingStudioApi::InvalidActionInputError` (422). Provider errors re-raise unchanged. MCP advertises the endpoint; this gem adds no MCP tool.
* Dummy mounts Recording Studio API `v0.21.3` (with Logs, Moveable, Icons, Admin, Redis, and Flatpack `0.1.341`).

### Upgrade notes

- Hosts that already mount Recording Studio API get `GET .../web_search` when this gem is loaded. No extra MCP registration. Callers cannot pick a search provider on the endpoint; the host default is used.
- No migration in this gem. Copy Recording Studio API migrations into the host if the dummy-style HTTP surface is new there.
- See [UPGRADING.md](UPGRADING.md#080).

## [0.7.0] - 2026-11-05

### Changed

* Require `recording_studio` `>= 6.3.0` and `flat_pack` `>= 0.1.341`. Development pins Recording Studio `v6.3.0` and Flatpack `v0.1.341`.
* Dummy pins move to Accessible `v0.24.1`, Trashable `v0.12.2`, Cache `v0.6.2`, Metrics `v0.7.2`, Logs `v0.7.3`, and Root Switchable `v0.11.5`. Admin stays at `v2.8.1`. AI stays at `v0.19.5`.
* Engine controllers call `recording_studio_layout`. `RecordingStudio::WebSearch.configuration.layout` defaults to `nil` and is validated by `RecordingStudio::Layout.accept`.
* Run-page close/back `anchor_url` only accepts relative `/` paths (`UrlSafety.safe_href` with `allow_external: false`).
* Rails locks move to `8.1.4.1`. Rack, Nokogiri, Loofah, rails-html-sanitizer, and the other bundler-audit findings on the root lock are refreshed.
* Drop leftover template files (`docs/gem_template/`, `UPDATE_SUMMARY.md`, `MIGRATION_NOTES.md`).

### Upgrade notes

- Install Recording Studio 6.3.0 or newer and Flatpack `>= 0.1.341` from GitHub.
- Set `config.layout` only when the host must override the default layout. `nil` keeps core's Default Layout.
- Close and back on the run page ignore absolute `anchor_url` values. Pass a relative path that starts with `/`.
- No migration. Search and admin behavior is otherwise unchanged.
- See [UPGRADING.md](UPGRADING.md#070).

## [0.6.1] - 2026-11-02

### Changed

* The search-run result rows render title, domain, and description with
  `FlatPack::Text` instead of raw `<span>` tags.
* The engine views need Flatpack `>= 0.1.331` (this repo already pins
  `v0.1.332`). The gemspec still does not declare `flat_pack`.

### Upgrade notes

- Hosts that render the run show page need Flatpack `>= 0.1.331`. Pin it from
  GitHub. There is no gemspec `flat_pack` dependency in this release.
- No migration. Search and admin behavior is unchanged.

## [0.6.0] - 2026-11-02

### Changed

* Require `recording_studio` `~> 6.1` (6.1 up to, but not including, 7). The gemspec no longer accepts 4.x.
* Development pins: Recording Studio `v6.3.0` and Flatpack `v0.1.332`.
* Dummy pins move to the current core-6 addon tags: Accessible `v0.24.0`,
  Admin `v2.8.1`, AI `v0.19.5`, Root Switchable `v0.11.3`, Metrics `v0.7.0`,
  Trashable `v0.12.0`, Cache `v0.6.0`, and Logs `v0.7.1`. Logs is a dummy pin
  because Admin 2.8 and AI 0.19 depend on it and it is not on RubyGems.
* The constant moves from `0.5.3` to `0.6.0`.

### Upgrade notes

- Install Recording Studio 6.1.0 or newer. Core 6 also needs Flatpack
  `>= 0.1.315` from GitHub (this repo pins `v0.1.332`).
- No migration in this gem. Search, usage metering, and admin screens keep
  the same behavior.
- Core 6 removed `recording_studio_page_nav` and
  `RecordingStudio::UsesDefaultLayout`. The run show page and the dummy shell
  call `flat_pack_page_nav` and `recording_studio_page_nav_right`. The run
  page draws `FlatPack::PageTitle` with the plain query. The default layout
  strips `content_for :title` and then escapes it again, so that slot is not
  used for the query and the query is never marked `html_safe`. The results
  column is `FlatPack::Stack` with `gap: :lg`. The close anchor defaults to
  `RecordingStudioAdmin.configuration.surface_for(:admin).path`.
- Dummy Admin uses `layout` instead of `engine_layout`. Dummy Root Switchable
  uses the layout name `recording_studio/default_layout`. Flatpack cards use
  `background:` instead of `style:`.
- See [UPGRADING.md](UPGRADING.md#060).

## [0.5.3] - 2026-11-02

### Changed

* Version `0.5.0` → `0.5.3` so `VERSION`, CHANGELOG, and the existing `v0.5.2` tag line up. Tags `v0.5.1` and `v0.5.2` already existed on main with no matching `VERSION` bump.
* Stop tracking SimpleCov output under `coverage/` and `test/dummy/coverage/`.
* Non-matrix GitHub Actions `ruby/setup-ruby` steps pin `ruby-version: '3.3'` so Security jobs boot on current ubuntu runners. Matrix test jobs still use `3.3` and `3.4`. The `.ruby-version` file is unchanged.

### Upgrade notes

- No migration or host code change is required.

## [0.5.2] - 2026-10-16

### Changed

* Dummy dependency bumps already tagged as `v0.5.2`: Recording Studio Trashable `v0.11.0` (#25) and Accessible `v0.18.0` (#24). `VERSION` in the gem stayed `0.5.0` on that tag.

## [0.5.1] - 2026-10-14

### Changed

* Dummy dependency bumps already tagged as `v0.5.1`: Recording Studio `v4.6.0` (#23), Accessible `v0.17.0` (#22), Admin `v2.3.0` (#21) and `v2.2.0` (#18), AI `v0.11.0` (#20), and Root Switchable `v0.9.0` (#19). `VERSION` in the gem stayed `0.5.0` on that tag.

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

[Unreleased]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.9.1...HEAD
[0.9.1]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.8.0...v0.9.0
[0.8.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.7.0...v0.8.0
[0.7.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.6.1...v0.7.0
[0.6.1]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.6.0...v0.6.1
[0.6.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.5.3...v0.6.0
[0.5.3]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.5.2...v0.5.3
[0.5.2]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.5.1...v0.5.2
[0.5.1]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.5.0...v0.5.1
[0.5.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/releases/tag/v0.1.0
