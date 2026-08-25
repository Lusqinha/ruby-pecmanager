# frozen_string_literal: true

require_relative "../../test_helper"

class InstallmentTextInputTest < Minitest::Test
  Input = Features::Installments::TextInput

  def parse(text) = Input.parse(text, today: Date.new(2026, 8, 25))

  def test_total_before_the_count_is_the_whole_purchase
    result = parse("1200 em 12x notebook")

    assert_equal 120_000, result[:total].cents
    assert_equal 12, result[:count]
    assert_equal "notebook", result[:description]
    assert_equal Date.new(2026, 8, 1), result[:first_month]
  end

  def test_a_value_after_the_count_is_the_installment
    result = parse("12x de 100 notebook")

    assert_equal 120_000, result[:total].cents
    assert_equal 12, result[:count]
  end

  def test_reads_a_starting_month_by_name
    result = parse("550 em 1x cnpj a partir de out")

    assert_equal Date.new(2026, 10, 1), result[:first_month]
    assert_equal 1, result[:count]
    assert_equal 55_000, result[:total].cents
  end

  def test_reads_a_numeric_starting_month
    assert_equal Date.new(2027, 3, 1), parse("300 em 3x curso a partir de 03/2027")[:first_month]
  end

  def test_ignores_text_without_a_count
    assert_nil parse("50 xis salada")
    refute Input.match?("50 xis salada")
    assert Input.match?("1200 em 12x notebook")
  end
  # "marmita" começa com "mar", "outros" com "out": mês só vale se a palavra
  # terminar ali ou for o nome por extenso.
  def test_a_word_that_starts_like_a_month_is_not_a_month
    result = parse("120 em marmita 4x")

    assert_equal Date.new(2026, 8, 1), result[:first_month]
    assert_equal "marmita", result[:description]
    assert_equal Date.new(2026, 8, 1), parse("3x de 50 em outros")[:first_month]
  end

  def test_accepts_the_month_written_in_full
    assert_equal Date.new(2026, 10, 1), parse("550 em 1x cnpj a partir de outubro")[:first_month]
    assert_equal Date.new(2027, 3, 1), parse("300 em 3x curso a partir de março")[:first_month]
  end

  def test_an_impossible_month_is_not_a_crash
    assert_nil parse("3x de 100 a partir de 13/2026")
    assert_nil parse("1200 em 12x a partir de 00/2027")
  end
end
