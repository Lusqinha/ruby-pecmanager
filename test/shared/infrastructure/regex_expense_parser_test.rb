# frozen_string_literal: true

require_relative "../../test_helper"

class RegexExpenseParserTest < Minitest::Test
  def parse(text) = Infrastructure::Parsing::RegexExpenseParser.new.parse(text, today: TODAY)

  def test_amount_and_description
    result = parse("35 mercado")

    assert_equal 3_500, result.amount.cents
    assert_equal "mercado", result.description
    assert_equal TODAY, result.spent_on
    assert_equal "regex", result.source
  end

  def test_relative_dates
    assert_equal TODAY - 1, parse("12,50 uber ontem").spent_on
    assert_equal TODAY - 2, parse("20 padaria anteontem").spent_on
    assert_equal TODAY - 3, parse("89,90 farmacia sexta").spent_on
    assert_equal Date.new(2026, 8, 10), parse("R$ 1.200 aluguel dia 10").spent_on
    assert_equal Date.new(2026, 7, 30), parse("50 gasolina 30/07").spent_on
  end

  def test_future_day_falls_back_to_the_previous_month
    assert_equal Date.new(2026, 8, 20), parse("30 cinema dia 20").spent_on
    assert_equal Date.new(2026, 7, 30), parse("30 cinema dia 30").spent_on
  end

  def test_returns_nil_without_an_amount
    assert_nil parse("lixo sem numero")
    assert_nil parse("")
  end
end

