# frozen_string_literal: true

require_relative "../test_helper"

# bot.rb is never loaded by the suite, so a stale require_relative in it only
# shows up when starting the bot for real. This catches it here instead.
class EntrypointTest < Minitest::Test
  ROOT = File.expand_path("../..", __dir__)

  def test_every_require_in_bot_rb_resolves
    missing = File.read(File.join(ROOT, "bot.rb"))
                  .scan(/require_relative ["'](.+?)["']/).flatten
                  .reject { |path| File.exist?(File.join(ROOT, "#{path}.rb")) }

    assert_empty missing, "require_relative apontando para arquivo inexistente"
  end

  def test_the_boot_file_lists_only_existing_paths
    globs = File.read(File.join(ROOT, "lib/config/boot.rb")).scan(/"(lib\/[^"]+)"/).flatten
    empty = globs.reject { |glob| Dir[File.join(ROOT, glob)].any? }

    assert_empty empty, "glob do boot.rb não casa com nenhum arquivo"
  end
end
