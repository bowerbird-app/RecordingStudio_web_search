Recording Studio Web Search install complete.

Next steps:

1. Review config/initializers/recording_studio_web_search.rb and set the Brave key.
2. If you use environment-specific settings, create config/recording_studio_web_search.yml.
3. This gem does not ship database tables. Skip migrations unless you add your own.
4. Run `bin/rails tailwindcss:build` if you use Tailwind CSS.
5. Mount routes are added at the configured mount path. Search itself is a library call and does not need a public route.
6. Keep strict recordable declarations enabled and add `recording_studio_recordable(...)` to every configured recordable before running `RecordingStudio.validate_recordable_declarations!`.
