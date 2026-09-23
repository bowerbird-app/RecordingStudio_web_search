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

This gem does not depend on `recording_studio_ai`. The AI gem should register a tool `web_search` version integer `1` whose executor calls `RecordingStudio::WebSearch.search` and returns `response.to_h`. Tool arguments: `query`, `country`, `language`, `freshness`, `count`.

## Dummy app

```bash
cd test/dummy
bin/rails db:setup
bin/dev
```

Sign in at `/users/sign_in` with `admin@admin.com` / `Password`. The home page is a signed-in search form.
