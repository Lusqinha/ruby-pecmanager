# frozen_string_literal: true

require_relative "../test_helper"

# Vertical slices only pay off if they stay independent. This fails the moment
# one slice reaches into another, or shared reaches into a slice.
class ArchitectureTest < Minitest::Test
  ROOT = File.expand_path("../../lib", __dir__)
  SLICES = %w[setup expense reports help].freeze

  def test_slices_do_not_reach_into_each_other
    violations = SLICES.flat_map do |slice|
      others = SLICES.reject { |other| other == slice }
      patterns = others.map { |other| /Features::#{other.capitalize}::/ }
      files("features/#{slice}").flat_map { |file| offences(file, patterns) }
    end

    assert_empty violations, "um slice referenciou outro:\n#{violations.join("\n")}"
  end

  def test_shared_never_depends_on_a_slice
    violations = files("shared").flat_map { |file| offences(file, [/Features::/]) }

    assert_empty violations, "shared referenciou um slice:\n#{violations.join("\n")}"
  end

  def test_domain_knows_no_gem_and_no_adapter
    patterns = [/\bSequel\b/, /\bTelegram\b/, /Infrastructure::/, /Interface::/, /Ports::/,
                /require ["']sequel/, /require ["']telegram/, /require ["']net\/http/]
    violations = files("shared/domain").flat_map { |file| offences(file, patterns) }

    assert_empty violations, "domínio contaminado:\n#{violations.join("\n")}"
  end

  def test_ports_declare_interfaces_without_naming_implementations
    violations = files("shared/ports").flat_map { |file| offences(file, [/Infrastructure::/, /Features::/, /\bSequel\b/]) }

    assert_empty violations
  end

  def test_nothing_outside_config_depends_on_the_composition_root
    violations = (SLICES.map { |slice| "features/#{slice}" } + ["shared"])
                 .flat_map { |dir| files(dir) }
                 .flat_map { |file| offences(file, [/Config::Container/]) }

    assert_empty violations
  end

  def test_slice_use_cases_do_not_talk_to_sequel_directly
    patterns = [/\bSequel\b/, /require ["']sequel/]
    violations = SLICES.flat_map { |slice| files("features/#{slice}").flat_map { |file| offences(file, patterns) } }

    assert_empty violations
  end

  def test_every_slice_exists_and_declares_a_handler
    SLICES.each do |slice|
      handler = File.join(ROOT, "features", slice, "handler.rb")

      assert_path_exists handler, "slice #{slice} sem handler"
    end
  end

  private

  def files(dir) = Dir[File.join(ROOT, dir, "**", "*.rb")]

  def offences(file, patterns)
    body = File.read(file)
    patterns.filter_map do |pattern|
      line = body.lines.find { |candidate| candidate.match?(pattern) && !candidate.strip.start_with?("#") }
      "#{file.sub("#{ROOT}/", '')}: #{line.strip}" if line
    end
  end
end
