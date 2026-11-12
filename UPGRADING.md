# Upgrading

## 0.8.0

This release registers a Recording Studio API search endpoint when that gem is
loaded. Search behavior is otherwise the same. There is no migration in this gem.

### What Changed

- `RecordingStudio::WebSearch::Api.register!` adds `GET web_search` as
  `web_search.search`. The handler authorizes the AccessGrant on
  `context.root_recording` at `:view`, then calls
  `RecordingStudio::WebSearch.search` with the request context as
  `attribution:`. Invalid queries raise `InvalidActionInputError` (HTTP 422).
  Provider failures raise `RecordingStudioApi::Error`.
- The AI custom tool is unchanged from 0.7.0.
- This gem still does not depend on `recording_studio_api`. The dummy app pins
  API `v0.21.3`, Moveable, Icons, Redis, Logs, Admin, and Flatpack `0.1.341`.
- The endpoint does not accept a `provider` parameter. Search uses the host
  default.

### Upgrade Steps

Install this gem at `0.8.0`. If the host already mounts Recording Studio API,
the endpoint appears after boot. Copy API migrations into the host if they are
not there yet:

```bash
bin/rails generate recording_studio_api:migrations
bin/rails db:migrate
```

Grant Accessible `:view` on the root used by the API client. No change is
required for hosts that only call `RecordingStudio::WebSearch.search` in Ruby.

No migration in this gem.

## 0.7.0

This release requires Recording Studio 6.3.0 or newer and Flatpack `>= 0.1.341`.
Search and admin screens keep the same jobs. There is no migration.

### What Changed

- The gemspec depends on `recording_studio` `>= 6.3.0` and `flat_pack` `>= 0.1.341`.
- `RecordingStudio::WebSearch.configuration.layout` defaults to `nil`. `nil` uses
  `RecordingStudio.configuration.layout`, then `recording_studio/default_layout`.
  Assign a layout name, `false`, or a callable that accepts `controller:`.
  Engine controllers call `recording_studio_layout`. Do not include
  `RecordingStudio::UsesDefaultLayout` and do not hard-code
  `layout "recording_studio/default_layout"`.
- Run show close/back reads `anchor_url` through Admin `UrlSafety` with
  `allow_external: false`, so only relative `/` paths become the PageNav close
  href.
- Result descriptions use Flatpack Text `size` and `style` only.
- Dummy pins: Accessible `v0.24.1`, Trashable `v0.12.2`, Cache `v0.6.2`,
  Metrics `v0.7.2`, Logs `v0.7.3`, Root Switchable `v0.11.5`. Admin stays
  `v2.8.1`. This gem does not depend on Admin.

### Upgrade Steps

Install Recording Studio 6.3.0 or newer. Pin Flatpack from GitHub. This repo
uses tag `v0.1.341`:

```ruby
gem "recording_studio", git: "https://github.com/bowerbird-app/RecordingStudio.git", tag: "v6.3.0"
gem "flat_pack", git: "https://github.com/bowerbird-app/flatpack.git", tag: "v0.1.341"
```

Leave `config.layout` unset unless the host must pick another layout. Pass
relative `anchor_url` values (paths that start with `/`) when linking to a run.

No migration.

## 0.6.1

This release needs Flatpack `>= 0.1.331` for the run show result copy. Search
and admin behavior is unchanged. There is no migration.

### What Changed

- Title, domain, and description on a saved search run render through
  `FlatPack::Text` (`as: :div` for title and domain, `as: :p` for description).
- The gemspec still does not add `flat_pack`. Hosts that mount the run page
  already need Flatpack from Recording Studio 6.

### Upgrade Steps

Keep Flatpack at `>= 0.1.331`. This repo pins `v0.1.332`:

```ruby
gem "flat_pack", git: "https://github.com/bowerbird-app/flatpack.git", tag: "v0.1.332"
```

No migration.

## 0.6.0

This release requires Recording Studio 6.1.0 or newer. Search, usage metering,
and admin screens keep the same behavior. There is no migration in this gem.

### What Changed

- The gemspec depends on `recording_studio` `~> 6.1` (6.1 up to, but not including, 7).
- The run show page renders `FlatPack::PageTitle` with the plain query and
  subtitle. Core 6's default layout strips `content_for :title` and then
  escapes that string again, so the query is not passed through that slot.
  The page calls `flat_pack_page_nav` for the back control and the close
  anchor. The close anchor defaults to the admin surface path. The results
  sit in `FlatPack::Stack` with `gap: :lg`. `recording_studio_page_nav` is
  gone in core 6. The Searches action still uses `recording_studio_page_nav_right`.
- The dummy app opts into the default layout with
  `helper RecordingStudio::LayoutHelper` and
  `layout "recording_studio/default_layout"`.
  `RecordingStudio::UsesDefaultLayout` is gone in core 6.
- Dummy Admin sets `config.layout` and `surface.layout`. `engine_layout` is
  gone in Admin 2.8. Dummy Root Switchable sets `config.layout` to the layout
  name. A symbol is not a layout setting in core 6.
- Flatpack cards take `background:` instead of `style:`.

### Upgrade Steps

Install Recording Studio 6.1.0 or newer. Core 6 depends on Flatpack
`>= 0.1.315`, which is not on RubyGems. Pin it from GitHub. This repo uses
tag `v0.1.332`:

```ruby
gem "recording_studio", git: "https://github.com/bowerbird-app/RecordingStudio.git", tag: "v6.3.0"
gem "flat_pack", git: "https://github.com/bowerbird-app/flatpack.git", tag: "v0.1.332"
```

Hosts that mount Admin or AI with this dummy's addon set also need Logs
`v0.7.1`. This gem does not depend on Logs, Admin, or AI.

No migration. Run `bin/rails generate recording_studio_web_search:migrations`
only if the host has not already copied the search-run table.

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
