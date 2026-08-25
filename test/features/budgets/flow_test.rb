# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class BudgetsFlowTest < SliceCase
  def setup
    super
    @factory.seed_user
  end

  def test_lists_every_budget_and_what_is_left
    reply = send_text("/budgets")

    assert_includes reply.text, "Mercado"
    assert_includes reply.text, "R$ 500,00"
    assert_includes reply.text, "Somam R$ 1.500,00"
  end

  def test_sets_a_fixed_budget
    reply = send_text("/budget mercado 800")

    assert_includes reply.text, "R$ 500,00 → R$ 800,00"
    assert_equal 80_000, budget("Mercado").cents_for(money(500_000)).cents
  end

  def test_sets_a_percentage_budget
    send_text("/budget transporte 10%")

    assert_equal 50_000, budget("Transporte").cents_for(money(500_000)).cents
    assert_includes send_text("/budgets").text, "10% = R$ 500,00"
  end

  def test_removes_a_budget
    send_text("/budget mercado livre")

    assert budget("Mercado").none?
    assert_includes send_text("/budgets").text, "sem limite"
  end

  def test_warns_when_the_budgets_pass_what_is_left
    reply = send_text("/budget mercado 4900")

    assert_includes reply.text, "acima do que sobra"
  end

  def test_a_command_without_a_value_asks_for_one
    reply = send_text("/budget mercado")

    assert_includes reply.text, "Não entendi o valor"
  end

  def test_unknown_category_lists_the_available_ones
    reply = send_text("/budget viagens 100")

    assert_includes reply.text, "Categoria não encontrada"
    assert_includes reply.text, "Mercado"
  end

  # Sem esse recorte "500 mercado" viraria comando em vez de gasto.
  def test_a_plain_expense_still_reaches_the_expense_slice
    with_regex_parser

    assert_includes send_text("35 mercado").text, "R$ 35,00"
  end

  private

  def budget(name)
    @factory.categories.for_user(3).find { |category| category.name == name }.limit
  end
end
