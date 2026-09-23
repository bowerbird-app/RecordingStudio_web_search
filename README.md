# Recording Studio Web Search

Provider-neutral web search for Recording Studio. Brave is the first provider. Callers use one API.

## Configuration

```ruby
RecordingStudio::WebSearch.configure do |config|
  config.provider = :brave
  config.brave_api_key = ENV["brave_search"]
end
```

Timeouts default to open 5, read 10, and write 5 seconds. Cost defaults to USD 5 per 1000 Brave requests. Instrumentation is on unless you set `config.instrumentation_enabled = false`.

## Basic search

```ruby
response = RecordingStudio::WebSearch.search(
  "Australian architecture",
  country: "AU",
  language: "en",
  freshness: "month",
  count: 10
)

response.results.each do |result|
  result.title
  result.url
  result.domain
  result.description
end

response.more_results?
response.provider
response.query
```

## Search options

Public keywords only. Unknown keywords raise `InvalidQueryError` before HTTP.

| Option | Default | Notes |
|---|---|---|
| `country:` | none | Two-letter code, sent uppercased |
| `language:` | none | Maps to Brave `search_lang` |
| `count:` | `10` | Integer 1..20 |
| `page:` | `0` | Page index 0..9. Brave receives this as `offset` |
| `safe_search:` | `:moderate` | `:off`, `:moderate`, or `:strict` |
| `freshness:` | none | `:day`, `:week`, `:month`, `:year`, or `YYYY-MM-DDtoYYYY-MM-DD` |
| `extra_snippets:` | `false` | When true, extra excerpts land on `result.snippets` |

Query text is a non-blank string, max 400 characters. There is no public `type:` in v1. Web search is the only operation.

## Response and results

`SearchResponse` has `query`, `provider`, `results`, `metadata`, and `more_results?`. `metadata` may include `estimated_cost_usd`, `result_count`, `page`, and `count`.

Each `SearchResult` has `title`, `url`, `description`, `snippets`, `published_at`, `domain`, and allowlisted `metadata`. Domain comes from the result URL host. `to_h` is JSON-safe (string keys, times as ISO 8601).

## Providers

Brave is first and the default. Callers stay on the neutral API. A second provider is one class plus one entry in the private `PROVIDERS` hash. There is no plugin loader.

## Instrumentation

Each public `search` call emits `search.recording_studio_web_search` when instrumentation is enabled, including calls that fail before HTTP.

Payload:

```ruby
{
  schema_version: 1,
  provider: :brave,
  operation: :web,
  query: "...",
  parameters: {},
  success: true,
  request_count: 1,
  estimated_cost_usd: 0.005,
  result_count: 10,
  error_type: nil
}
```

Duration is `ActiveSupport::Notifications::Event#duration`. The payload never includes the API key or the exception object.

## Recording Studio AI

This gem does not depend on `recording_studio_ai`. When that gem is loaded, this one registers a custom tool `web_search` at version `1`. The executor calls `RecordingStudio::WebSearch.search` and returns `response.to_h`.

Tool arguments are `query` (required), `country`, `language`, `freshness`, and `count`.

The dummy app installs Recording Studio AI at `/recording_studio_ai` and turns on the Recording Studio AI admin section. The registered tool is listed there.

## Admin

Staff screens register when `recording_studio_admin` is loaded. They read a search-run log. Result pages stay out of the tree. Each run keeps a snapshot of title, URL, domain, and description, and the Brave key stays off the page.

Mount admin on an admin root and grant Accessible access to that root. The Web search section links to Providers and Searches. Providers lists whoever can answer a search. Searches charts each day of the last 4 weeks, with filters for provider, dates, and status. The results count opens that run. Mount this engine so that page has a URL:

```ruby
mount RecordingStudio::WebSearch::Engine, at: "/addons/recording"
```

If the host also uses root switchable, skip root resolution on the admin controllers. A selected workspace is a different root, and admin will refuse the page until that check is skipped.

Admin frames need Turbo. The dummy imports `@hotwired/turbo-rails` so the providers list, the searches chart, and the search log load in the browser. Open a section with `anchor_url` set to the admin root so the close control can leave.

Copy the log migration into the host app:

```bash
bin/rails generate recording_studio_web_search:migrations
bin/rails db:migrate
```

## Dummy app

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The home page is a signed-in search form.
