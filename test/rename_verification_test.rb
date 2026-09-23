# frozen_string_literal: true

require "yaml"
require_relative "simplecov_helper"
require "minitest/autorun"

class RenameVerificationTest < Minitest::Test
  def setup
    @root = File.expand_path("..", __dir__)
    @gem_name = detect_gem_name
    @pascal_name = "RecordingStudio::WebSearch"
    @kebab_name = to_kebab_case(@gem_name)
  end

  def test_gemspec_file_exists
    gemspec_path = File.join(@root, "#{@gem_name}.gemspec")
    assert File.exist?(gemspec_path),
           "Expected gemspec at #{gemspec_path}"
  end

  def test_main_lib_file_exists
    lib_path = File.join(@root, "lib", "#{@gem_name}.rb")
    assert File.exist?(lib_path),
           "Expected main lib file at #{lib_path}"
  end

  def test_lib_directory_exists
    lib_dir = File.join(@root, "lib", @gem_name)
    assert Dir.exist?(lib_dir),
           "Expected lib directory at #{lib_dir}"
  end

  def test_version_file_exists
    version_path = File.join(@root, "lib", @gem_name, "version.rb")
    assert File.exist?(version_path),
           "Expected version file at #{version_path}"
  end

  def test_engine_file_exists
    engine_path = File.join(@root, "lib", @gem_name, "engine.rb")
    assert File.exist?(engine_path),
           "Expected engine file at #{engine_path}"
  end

  def test_controllers_directory_exists
    controllers_dir = File.join(@root, "app", "controllers", @gem_name)
    assert Dir.exist?(controllers_dir),
           "Expected controllers directory at #{controllers_dir}"
  end

  def test_views_directory_exists
    views_dir = File.join(@root, "app", "views", @gem_name)
    assert Dir.exist?(views_dir),
           "Expected views directory at #{views_dir}"
  end

  def test_gemspec_has_correct_name
    content = read_gemspec
    assert_match(/spec\.name\s*=\s*["']#{Regexp.escape(@gem_name)}["']/,
                 content,
                 "Gemspec should have name = '#{@gem_name}'")
  end

  def test_gemspec_references_correct_version_module
    content = read_gemspec
    assert_match(/#{@pascal_name}::VERSION/, content,
                 "Gemspec should reference #{@pascal_name}::VERSION")
  end

  def test_gemspec_requires_correct_version_file
    content = read_gemspec
    assert_match(%r{require_relative\s+["']lib/#{Regexp.escape(@gem_name)}/version["']}, content,
                 "Gemspec should require lib/#{@gem_name}/version")
  end

  def test_main_lib_defines_correct_module
    content = read_main_lib
    assert_nested_product_module(content, "Main lib")
  end

  def test_main_lib_requires_version
    content = read_main_lib
    assert_match(%r{require\s+["']#{Regexp.escape(@gem_name)}/version["']}, content,
                 "Main lib should require #{@gem_name}/version")
  end

  def test_main_lib_requires_engine
    content = read_main_lib
    assert_match(%r{require\s+["']#{Regexp.escape(@gem_name)}/engine["']}, content,
                 "Main lib should require #{@gem_name}/engine")
  end

  def test_version_file_defines_correct_module
    content = read_version_file
    assert_nested_product_module(content, "Version file")
  end

  def test_version_file_has_version_constant
    content = read_version_file
    assert_match(/VERSION\s*=\s*["']\d+\.\d+\.\d+["']/, content,
                 "Version file should define VERSION constant")
  end

  def test_engine_file_defines_correct_module
    content = read_engine_file
    assert_nested_product_module(content, "Engine file")
  end

  def test_engine_isolates_correct_namespace
    content = read_engine_file
    assert_match(/isolate_namespace\s+RecordingStudio::WebSearch/, content,
                 "Engine should isolate_namespace RecordingStudio::WebSearch")
  end

  def test_routes_references_correct_engine
    content = read_routes_file
    assert_match(/RecordingStudio::WebSearch::Engine\.routes\.draw/, content,
                 "Routes should reference RecordingStudio::WebSearch::Engine")
  end

  def test_application_controller_exists
    path = nested_controller_path("application_controller.rb")
    assert File.exist?(path),
           "Application controller should exist at #{path}"
  end

  def test_application_controller_has_correct_module
    content = File.read(nested_controller_path("application_controller.rb"))
    assert_nested_product_module(content, "Application controller")
  end

  def test_home_controller_exists
    path = nested_controller_path("home_controller.rb")
    assert File.exist?(path),
           "Home controller should exist at #{path}"
  end

  def test_home_controller_has_correct_module
    content = File.read(nested_controller_path("home_controller.rb"))
    assert_nested_product_module(content, "Home controller")
  end

  def test_no_old_gem_template_references_in_ruby_files
    skip if @gem_name == "gem_template"

    ruby_files = Dir.glob(File.join(@root, "**", "*.rb"))
    ruby_files.reject! do |file|
      file.include?("test/dummy") ||
        file.include?("rename_verification_test.rb") ||
        file.include?("rename_gem_identity_test.rb")
    end

    files_with_old_refs = []

    ruby_files.each do |file|
      content = File.read(file)
      files_with_old_refs << file if content.include?("gem_template") || content.include?("GemTemplate")
    end

    assert files_with_old_refs.empty?,
           "Found old 'gem_template' references in:\n#{files_with_old_refs.join("\n")}"
  end

  def test_no_old_gem_template_directories
    skip if @gem_name == "gem_template"

    old_dirs = [
      File.join(@root, "lib", "gem_template"),
      File.join(@root, "app", "controllers", "gem_template"),
      File.join(@root, "app", "views", "gem_template")
    ]

    existing_old_dirs = old_dirs.select { |d| Dir.exist?(d) }

    assert existing_old_dirs.empty?,
           "Found old 'gem_template' directories:\n#{existing_old_dirs.join("\n")}"
  end

  def test_no_old_gemspec_file
    skip if @gem_name == "gem_template"

    old_gemspec = File.join(@root, "gem_template.gemspec")
    refute File.exist?(old_gemspec),
           "Old gemspec file should not exist: #{old_gemspec}"
  end

  def test_no_old_main_lib_file
    skip if @gem_name == "gem_template"

    old_lib = File.join(@root, "lib", "gem_template.rb")
    refute File.exist?(old_lib),
           "Old main lib file should not exist: #{old_lib}"
  end

  def test_readme_has_no_leftover_template_identity_after_rename
    skip if @gem_name == "gem_template"

    content = File.read(File.join(@root, "README.md"))
    refute_includes content, "GemTemplate",
                    "README.md still contains leftover GemTemplate identity"
    refute_match %r{bowerbird-app/gem_template(?:["'/]|$)}, content,
                 "README.md still points at bowerbird-app/gem_template"
    refute_includes content, "https://github.com/bowerbird-app/RecordingStudio_gem_template",
                    "README.md still points at the template homepage"
  end

  def test_changelog_has_no_leftover_template_identity_after_rename
    skip if @gem_name == "gem_template"

    content = File.read(File.join(@root, "CHANGELOG.md"))
    refute_includes content, "GemTemplate",
                    "CHANGELOG.md still contains leftover GemTemplate identity"
    refute_match %r{bowerbird-app/gem_template(?:["'/]|$)}, content,
                 "CHANGELOG.md still points at bowerbird-app/gem_template"
    refute_includes content, "https://github.com/bowerbird-app/RecordingStudio_gem_template",
                    "CHANGELOG.md still points at the template homepage"
  end

  def test_gemspec_homepage_has_no_leftover_template_identity_after_rename
    skip if @gem_name == "gem_template"

    content = read_gemspec
    refute_includes content, "GemTemplate",
                    "Gemspec still contains leftover GemTemplate identity"
    refute_match %r{bowerbird-app/gem_template(?:["'/]|$)}, content,
                 "Gemspec still points at bowerbird-app/gem_template"
    refute_includes content, "https://github.com/bowerbird-app/RecordingStudio_gem_template",
                    "Gemspec still points at the template homepage"
  end

  def test_version_file_is_loadable
    $LOAD_PATH.unshift(File.join(@root, "lib")) unless $LOAD_PATH.include?(File.join(@root, "lib"))

    begin
      require "#{@gem_name}/version"
      mod = Object.const_get(@pascal_name)
      assert_kind_of Module, mod, "#{@pascal_name} should be a module"
    rescue LoadError => e
      flunk "Could not load version file: #{e.message}"
    rescue NameError => e
      flunk "Module #{@pascal_name} not defined: #{e.message}"
    end
  end

  def test_version_constant_is_accessible
    $LOAD_PATH.unshift(File.join(@root, "lib")) unless $LOAD_PATH.include?(File.join(@root, "lib"))

    begin
      require "#{@gem_name}/version"
      mod = Object.const_get(@pascal_name)
      refute_nil mod::VERSION, "#{@pascal_name}::VERSION should be defined"
    rescue LoadError, NameError => e
      flunk "Could not access VERSION: #{e.message}"
    end
  end

  def test_gem_is_loadable_with_rails
    skip("Rails not loaded - run within dummy app") unless defined?(::Rails::Engine)

    begin
      require @gem_name
      mod = Object.const_get(@pascal_name)
      assert_kind_of Module, mod, "#{@pascal_name} should be a module"
      assert_kind_of Class, mod::Engine, "#{@pascal_name}::Engine should be a class"
      refute defined?(RecordingStudioWebSearch), "there is no compatibility alias"
    rescue LoadError => e
      flunk "Could not load gem: #{e.message}"
    rescue NameError => e
      flunk "Module or Engine not defined: #{e.message}"
    end
  end

  def test_generator_directory_exists
    generator_dir = File.join(@root, "lib", "generators", @gem_name)
    assert Dir.exist?(generator_dir),
           "Expected generator directory at #{generator_dir}"
  end

  def test_install_generator_exists
    generator_path = File.join(@root, "lib", "generators", @gem_name, "install", "install_generator.rb")
    assert File.exist?(generator_path),
           "Expected install generator at #{generator_path}"
  end

  def test_install_generator_has_correct_module
    generator_path = File.join(@root, "lib", "generators", @gem_name, "install", "install_generator.rb")
    skip unless File.exist?(generator_path)

    content = File.read(generator_path)
    assert_nested_product_module(content, "Install generator")
    assert_includes content, 'namespace "recording_studio_web_search:install"'
  end

  private

  def detect_gem_name
    identity_file = File.join(@root, ".gem_identity.yml")
    if File.exist?(identity_file)
      config = YAML.load_file(identity_file)
      return config["current_name"] if config["current_name"]
    end

    gemspec_files = Dir.glob(File.join(@root, "*.gemspec"))
    return File.basename(gemspec_files.first, ".gemspec") if gemspec_files.any?

    lib_dirs = Dir.glob(File.join(@root, "lib", "*")).select { |f| File.directory?(f) }
    lib_dirs.reject! { |d| File.basename(d) == "generators" }
    return File.basename(lib_dirs.first) if lib_dirs.any?

    raise "Could not detect gem name"
  end

  def to_pascal_case(str)
    str.split("_").map(&:capitalize).join
  end

  def nested_controller_path(filename)
    File.join(@root, "app", "controllers", "recording_studio", "web_search", filename)
  end

  def assert_nested_product_module(content, label)
    assert_match(/module RecordingStudio\n  module WebSearch/, content,
                 "#{label} should define RecordingStudio::WebSearch")
    refute_match(/module RecordingStudioWebSearch/, content,
                 "#{label} should not define RecordingStudioWebSearch")
  end

  def to_kebab_case(str)
    str.tr("_", "-")
  end

  def read_gemspec
    File.read(File.join(@root, "#{@gem_name}.gemspec"))
  end

  def read_main_lib
    File.read(File.join(@root, "lib", "#{@gem_name}.rb"))
  end

  def read_version_file
    File.read(File.join(@root, "lib", @gem_name, "version.rb"))
  end

  def read_engine_file
    File.read(File.join(@root, "lib", @gem_name, "engine.rb"))
  end

  def read_routes_file
    File.read(File.join(@root, "config", "routes.rb"))
  end
end
