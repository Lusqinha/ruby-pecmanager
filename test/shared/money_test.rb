# frozen_string_literal: true

require_relative "../test_helper"

class MoneyTest < Minitest::Test
  def test_arithmetic_stays_in_cents
    assert_equal 1_500, (money(1_000) + money(500)).cents
    assert_equal 500, (money(1_000) - money(500)).cents
    assert_equal 3_000, (money(1_000) * 3).cents
  end

  def test_percentage_truncates_instead_of_floating
    assert_equal 33, money(100).percentage(33).cents
    assert_equal 100_000, money(500_000).percentage(20).cents
  end

  def test_divided_over_rounds_up_so_the_goal_is_reached
    assert_equal 334, money(1_000).divided_over(3).cents
    assert_equal 1_000, money(1_000).divided_over(0).cents
  end

  def test_comparable_and_equality
    assert money(200) > money(100)
    assert_equal money(100), money(100)
    assert_equal money(500), [money(100), money(500)].max
  end
end
