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
