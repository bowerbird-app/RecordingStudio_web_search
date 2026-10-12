# frozen_string_literal: true

require "test_helper"
require "yaml"

class LocalesTest < ActiveSupport::TestCase
  RUNS_KEYS = {
    "searches" => "Searches"
  }.freeze

  EMPTY_KEYS = {
    "nothing_came_back" => "Nothing came back.",
    "nothing_turned_up" => "Nothing turned up.",
    "pages_not_kept" => "These pages were not kept."
  }.freeze

  ADMIN_KEYS = {
    "admin.section.title" => "Web search",
    "admin.section.subtitle" => "See who searches, what failed, and what it cost.",
    "admin.links.view_providers" => "View providers",
    "admin.links.view_searches" => "View searches",
    "admin.screens.providers.title" => "Providers",
    "admin.screens.searches.title" => "Searches",
    "admin.summary.searches" => "Searches",
    "admin.chart.searches_title" => "Searches",
    "admin.chart.searches_series" => "Searches",
    "admin.chart.failures_series" => "Failures",
    "admin.widgets.providers.title" => "Providers",
    "admin.widgets.providers.info" =>
      "Brave is ready when the server has a key. This page never shows the key.",
    "admin.widgets.failures.title" => "Failures",
    "admin.widgets.failures.info" => "Searches that did not come back."
  }.freeze

  test "engine ships only english locale files" do
    files = Dir[File.join(engine_locales_dir, "*")].map { |path| File.basename(path) }

    assert_equal ["en.yml"], files.sort
  end

  test "engine exposes config/locales for rails i18n load path" do
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    engine_locale_files = RecordingStudio::WebSearch::Engine.paths["config/locales"].existent
                                                            .map { |path| File.expand_path(path) }

    assert_includes engine_locale_files, locale_path
  end

  test "lib ruby sources never append i18n load path" do
    lib_root = File.expand_path("../lib", __dir__)
    sources = Dir[File.join(lib_root, "**", "*.rb")]
    assert_predicate sources, :any?

    sources.each do |path|
      source = File.read(path)

      refute_includes source, "i18n.load_path",
                      "#{path} must not append app.config.i18n.load_path"
      refute_includes source, "I18n.load_path",
                      "#{path} must not append I18n.load_path"
    end
  end

  test "english run interface keys resolve without missing translations" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        RUNS_KEYS.each do |key, english|
          full_key = "recording_studio.web_search.runs.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        EMPTY_KEYS.each do |key, english|
          full_key = "recording_studio.web_search.runs.empty.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
        end

        ADMIN_KEYS.each do |key, english|
          full_key = "recording_studio.web_search.#{key}"
          translation = I18n.t(full_key, default: nil)

          assert_equal english, translation, "#{full_key} should resolve to #{english.inspect}"
          assert_equal english, I18n.t(full_key, raise: true)
          assert_equal english, RecordingStudio::WebSearch::Copy.t(key, default: english)
        end
      end
    end
  end

  test "en.yml nests keys under recording_studio.web_search" do
    tree = locale_tree(File.join(engine_locales_dir, "en.yml"), "en")
           .fetch("recording_studio")
           .fetch("web_search")
           .fetch("runs")

    assert_equal RUNS_KEYS.fetch("searches"), tree.fetch("searches")
    assert_equal EMPTY_KEYS, tree.fetch("empty").transform_keys(&:to_s)
  end

  test "copy helper passes english default" do
    with_engine_locales_loaded do
      I18n.with_locale(:en) do
        assert_equal "Searches",
                     RecordingStudio::WebSearch::Copy.t("runs.searches", default: "Searches")
      end
    end
  end

  private

  def engine_locales_dir
    File.expand_path("../config/locales", __dir__)
  end

  def locale_tree(path, locale)
    YAML.safe_load_file(path, aliases: true).fetch(locale)
  end

  def with_engine_locales_loaded
    locale_path = File.expand_path(File.join(engine_locales_dir, "en.yml"))
    original_load_path = I18n.load_path.dup

    I18n.load_path |= [locale_path]
    I18n.reload!
    yield
  ensure
    I18n.load_path.replace(original_load_path)
    I18n.reload!
  end
end
