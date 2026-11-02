# Migration Notes

## Current Requirements

- Ruby 3.3 or newer
- Rails 8.1 or newer
- Recording Studio 6.1+ (`>= 6.1.0` in the gemspec; dummy GitHub tag `v6.3.0`)
- Accessible dummy tag `v0.24.0`, Root Switchable `v0.11.3`, Trashable `v0.12.0`, Metrics `v0.7.0`, Cache `v0.6.0`, Logs `v0.7.1`, Admin `v2.8.1`, AI `v0.19.5`
- FlatPack dummy tag `v0.1.332`
- Public RubyGems and GitHub access for dependency installation

## Verification

Install both bundles and run the complete gem and dummy app test path:

```bash
bundle install
BUNDLE_GEMFILE=test/dummy/Gemfile bundle install
bundle exec rake test:all
```

Run the dummy app from its directory for browser verification:

```bash
cd test/dummy
bin/dev
```

Use the [FlatPack repository](https://github.com/bowerbird-app/flatpack) and the live FlatPack demo linked from the top-level README for current component documentation.
