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
end
