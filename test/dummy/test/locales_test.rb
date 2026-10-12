# frozen_string_literal: true

require "test_helper"

class LocalesTest < ActiveSupport::TestCase
  test "rails i18n load path includes the web search gem english locale file" do
    locale_path = RecordingStudio::WebSearch::Engine.root.join("config/locales/en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(locale_path)
    assert_equal "Searches", I18n.t("recording_studio.web_search.runs.searches", raise: true)
  end

  test "boot-loaded host override for failures widget info is on the i18n load path" do
    host_path = Rails.root.join("config/locales/recording_studio_web_search_host.en.yml").to_s

    assert_includes I18n.load_path.map { |path| File.expand_path(path) }, File.expand_path(host_path)
    assert_equal "HOST searches that did not come back.",
                 I18n.t("recording_studio.web_search.admin.widgets.failures.info", raise: true)
  end
end

