# frozen_string_literal: true

source "https://rubygems.org"

# Specify your gem's dependencies in recording_studio_web_search.gemspec
gemspec

# flat_pack and recording_studio are not published to RubyGems.
gem "flat_pack", github: "bowerbird-app/flatpack", tag: "v0.1.376"
gem "recording_studio", github: "bowerbird-app/RecordingStudio", tag: "v7.0.0"
# Keep the current lock. Do not bump view_component with this sweep.
gem "view_component", "4.20.0"

gem "devise"
gem "puma", "8.1.0"
gem "sprockets-rails"

group :development, :test do
  gem "debug"
  gem "minitest", "~> 5.25"
  gem "simplecov", require: false
end

group :development do
  gem "rubocop", require: false
  gem "rubocop-rails", require: false
end
