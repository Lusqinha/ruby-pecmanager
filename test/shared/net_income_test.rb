# frozen_string_literal: true

require_relative "../test_helper"

class NetIncomeTest < Minitest::Test
  def money(cents) = Domain::Money.new(cents)

  # Os números do planejamento real: PJ 4.200 com Simples, INSS e contabilidade.
  def plan
    Domain::FinancialPlan.new(
      salary: money(420_000),
      fixed_costs: [
        Domain::FixedCost.new(name: "Imposto", amount: money(600), kind: "pct", deduction: true),
        Domain::FixedCost.new(name: "INSS", amount: money(17_831), deduction: true),
        Domain::FixedCost.new(name: "Contabilidade", amount: money(25_000), deduction: true),
        Domain::FixedCost.new(name: "Aluguel", amount: money(90_000))
      ]
    )
  end

  def test_net_income_discounts_only_the_deductions
    assert_equal 351_969, plan.net_income.cents
  end

  def test_living_costs_leave_the_deductions_out
    assert_equal 90_000, plan.living_costs.cents
  end
end
