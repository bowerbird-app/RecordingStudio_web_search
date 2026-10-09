# frozen_string_literal: true

require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "rails i18n load path includes the web search gem english locale file" do
    locale_path = RecordingStudio::WebSearch::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
    assert_equal "Searches", I18n.t("recording_studio.web_search.runs.searches", raise: true)
  end
end
