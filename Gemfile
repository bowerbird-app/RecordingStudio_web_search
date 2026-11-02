# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_web_search.gemspec
gemspec

# flat_pack and recording_studio are not published to RubyGems. Core 6.3 requires flat_pack >= 0.1.315.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.332"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v6.3.0"

gem "devise"
gem "puma"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
