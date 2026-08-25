# frozen_string_literal: true

require_relative "../test_helper"

class MoneyParserTest < Minitest::Test
  def parse(text) = Interface::MoneyParser.parse(text)

  def test_parses_pt_br_and_us_notation
    assert_equal 120_050, parse("R$ 1.200,50").cents
    assert_equal 120_000, parse("1.200").cents
    assert_equal 1_250, parse("12,50").cents
    assert_equal 1_250, parse("12.50").cents
    assert_equal 120_000, parse("1200").cents
    assert_equal 3_500, parse("gastei 35 no mercado").cents
  end

  def test_comma_is_always_decimal_in_pt_br
    assert_equal 1_299, parse("12,999").cents
  end

  def test_returns_nil_without_a_number
    assert_nil parse("mercado")
    assert_nil parse(nil)
    assert_nil parse("")
  end
end

class BrlFormatterTest < Minitest::Test
  def format(cents) = Interface::Brl.format(money(cents))

  def test_formats_pt_br
    assert_equal "R$ 0,00", format(0)
    assert_equal "R$ 35,00", format(3_500)
    assert_equal "R$ 1.234.567,89", format(123_456_789)
    assert_equal "-R$ 10,50", format(-1_050)
  end

  def test_bar_reflects_usage
    bar, pct = Interface::Brl.bar(money(5_000), money(10_000))

    assert_equal 50, pct
    assert_equal "█████░░░░░", bar
  end

  def test_bar_saturates_over_the_limit
    bar, pct = Interface::Brl.bar(money(30_000), money(10_000))

    assert_equal 300, pct
    assert_equal "██████████", bar
  end
end
