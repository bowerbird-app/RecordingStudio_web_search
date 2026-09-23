# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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

[0.2.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/bowerbird-app/RecordingStudio_web_search/releases/tag/v0.1.0
