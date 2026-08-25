# frozen_string_literal: true

require_relative "../../test_helper"

class InputParserTest < Minitest::Test
  def parse(step, text) = Features::Setup::InputParser.new.parse(step: step, text: text)

  def test_commands_are_step_independent
    assert_equal :back, parse(:salary, "/voltar").name
    assert_equal :skip, parse(:budgets, "/pular").name
    assert_equal :cancel, parse(:goals, "/cancelar").name
    assert_equal :preset, parse(:categories, "preset").name
    assert_equal :confirm, parse(:confirm, "confirmar").name
    assert_equal :done, parse(:fixed_costs, "pronto").name
  end

  def test_salary_becomes_an_amount
    input = parse(:salary, "R$ 4.200,50")

    assert_instance_of Features::Setup::Input::Amount, input
    assert_equal 420_050, input.money.cents
  end

  def test_budget_reads_percentage_or_amount
    assert_equal 15, parse(:budgets, "15%").value
    assert_equal 30_000, parse(:budgets, "R$ 300").money.cents
    assert_instance_of Features::Setup::Input::Unknown, parse(:budgets, "sei lá")
  end

  def test_categories_split_on_commas
    input = parse(:categories, "mercado, rolê, pet")

    assert_equal %w[Mercado Rolê Pet], input.items.map { |item| item[:name] }
  end

  def test_fixed_cost_with_due_day
    item = parse(:fixed_costs, "aluguel 1200 dia 10").entities.first

    assert_equal "aluguel", item.name
    assert_equal 120_000, item.amount.cents
    assert_equal 10, item.due_day
  end

  def test_multiple_items_in_one_message
    input = parse(:fixed_costs, "aluguel 1200 dia 10\nluz 180")

    assert_equal 2, input.entities.size
  end

  def test_subscription_cycle
    assert_equal Domain::Subscription::MONTHLY, parse(:subscriptions, "netflix 39,90 dia 5").entities.first.cycle
    assert_equal Domain::Subscription::YEARLY, parse(:subscriptions, "dominio 60 anual").entities.first.cycle
  end

  def test_goal_with_and_without_deadline
    with_deadline = parse(:goals, "reserva 10000 até 12/2027").entities.first

    assert_equal Date.new(2027, 12, 1), with_deadline.deadline
    assert_equal 1_000_000, with_deadline.target.cents
    assert_nil parse(:goals, "viagem 3000").entities.first.deadline
  end

  def test_garbage_becomes_unknown
    assert_instance_of Features::Setup::Input::Unknown, parse(:fixed_costs, "?!")
    assert_instance_of Features::Setup::Input::Unknown, parse(:salary, "muito dinheiro")
  end
end
