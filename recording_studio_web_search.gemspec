# frozen_string_literal: true

require_relative "lib/recording_studio_web_search/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_web_search"
  spec.version     = RecordingStudio::WebSearch::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_web_search"
  spec.summary     = "Provider-neutral web search for Recording Studio"
  spec.description = "A Recording Studio addon that searches the public web through a provider-neutral API. " \
                     "Brave is the first provider."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/bowerbird-app/RecordingStudio_web_search"
  spec.metadata["changelog_uri"] = "https://github.com/bowerbird-app/RecordingStudio_web_search/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
