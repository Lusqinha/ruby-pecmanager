# frozen_string_literal: true

require_relative "../test_helper"

class MonthParserTest < Minitest::Test
  def parse(text) = Interface::MonthParser.parse(text, today: TODAY) # TODAY: 24/08/2026

  def test_reads_the_short_name_with_a_two_digit_year
    assert_equal Date.new(2026, 10, 1), parse("out/26")
  end

  def test_reads_numbers_with_any_separator
    assert_equal Date.new(2026, 10, 1), parse("10/2026")
    assert_equal Date.new(2026, 9, 1), parse("09-26")
  end

  def test_reads_the_full_name_with_accents
    assert_equal Date.new(2027, 3, 1), parse("março")
  end

  # Sem ano, o mês pedido é o próximo que vier: pedir um mês já vencido é raro.
  def test_a_month_without_a_year_looks_forward
    assert_equal Date.new(2026, 10, 1), parse("outubro")
    assert_equal Date.new(2027, 1, 1), parse("janeiro")
    assert_equal Date.new(2026, 8, 1), parse("agosto")
  end

  def test_refuses_what_is_not_a_month
    assert_nil parse("banana")
    assert_nil parse("13/26")
    assert_nil parse("")
  end
end
