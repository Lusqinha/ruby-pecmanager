# frozen_string_literal: true

require_relative "../test_helper"

class FixedCostTest < Minitest::Test
  def money(cents) = Domain::Money.new(cents)

  def test_a_fixed_deduction_is_its_own_amount
    item = Domain::FixedCost.new(name: "Contadora", amount: money(25_000), deduction: true)

    assert_equal 25_000, item.monthly_amount(money(420_000)).cents
    assert item.deduction?
  end

  def test_a_percentage_deduction_is_calculated_over_the_salary
    # 600 centésimos de ponto percentual = 6,00%
    item = Domain::FixedCost.new(name: "Imposto", amount: money(600), kind: "pct", deduction: true)

    assert_equal 25_200, item.monthly_amount(money(420_000)).cents
  end

  def test_a_plain_fixed_cost_is_not_a_deduction
    item = Domain::FixedCost.new(name: "Aluguel", amount: money(90_000))

    refute item.deduction?
    assert_equal 90_000, item.monthly_amount(money(420_000)).cents
  end
end
