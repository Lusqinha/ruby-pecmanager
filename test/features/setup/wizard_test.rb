# frozen_string_literal: true

require_relative "../../test_helper"

class WizardTest < Minitest::Test
  include Features::Setup

  def apply(step, draft, input) = Wizard.apply(step: step, draft: draft, input: input)

  def command(name) = Input::Command.new(name)

  def amount(cents) = Input::Amount.new(money(cents))

  def with_budgets(limit_input = Input::Percentage.new(10))
    transition = apply(:salary, Draft.new, amount(500_000))
    transition = apply(:categories, transition.draft, command(:preset))
    Presets.size.times { transition = apply(:budgets, transition.draft, limit_input) }
    transition
  end

  def test_starts_by_asking_how_the_money_arrives
    transition = Wizard.start

    assert_equal :income_type, transition.step
    assert_nil transition.draft.salary
  end

  def test_salary_rejects_non_amounts_and_stays
    transition = apply(:salary, Draft.new, Input::Unknown.new("muito dinheiro"))

    assert transition.invalid?
    assert_equal :invalid_amount, transition.error
    assert_equal :salary, transition.step
  end

  def test_preset_fills_categories
    transition = apply(:categories, Draft.new(salary: money(500_000)), command(:preset))

    assert_equal Presets.size, transition.draft.categories.size
    assert_includes transition.draft.categories.first.keywords, "supermercado"
    assert_equal :budgets, transition.step
  end

  def test_custom_categories
    input = Input::Categories.new([{ name: "Mercado", keywords: [] }, { name: "Pet", keywords: [] }])
    transition = apply(:categories, Draft.new(salary: money(500_000)), input)

    assert_equal %w[Mercado Pet], transition.draft.categories.map(&:name)
  end

  def test_budget_accepts_percentage_fixed_and_skip
    transition = apply(:categories, Draft.new(salary: money(500_000)),
                       Input::Categories.new([{ name: "A" }, { name: "B" }, { name: "C" }].map { |c| c.merge(keywords: []) }))
    transition = apply(:budgets, transition.draft, Input::Percentage.new(15))
    transition = apply(:budgets, transition.draft, amount(30_000))
    transition = apply(:budgets, transition.draft, command(:skip))

    limits = transition.draft.categories.map(&:limit)

    assert limits[0].percent?
    assert_equal 15, limits[0].value
    assert limits[1].fixed?
    assert limits[2].none?
    assert_equal :fixed_costs, transition.step
  end

  def test_budget_rejects_percentages_over_one_hundred
    transition = apply(:categories, Draft.new(salary: money(500_000)),
                       Input::Categories.new([{ name: "A", keywords: [] }]))
    transition = apply(:budgets, transition.draft, Input::Percentage.new(150))

    assert transition.invalid?
    assert_equal 0, transition.draft.budget_index
  end

  def test_back_inside_the_budget_loop
    transition = apply(:categories, Draft.new(salary: money(500_000)),
                       Input::Categories.new([{ name: "A", keywords: [] }, { name: "B", keywords: [] }]))
    transition = apply(:budgets, transition.draft, amount(10_000))

    assert_equal 1, transition.draft.budget_index

    transition = apply(:budgets, transition.draft, command(:back))

    assert_equal 0, transition.draft.budget_index
  end

  def test_back_from_fixed_costs_lands_on_the_last_category
    transition = apply(:fixed_costs, with_budgets.draft, command(:back))

    assert_equal :budgets, transition.step
    assert_equal Presets.size - 1, transition.draft.budget_index
  end

  def test_collections_accumulate_until_done
    draft = with_budgets.draft
    item = Domain::FixedCost.new(name: "aluguel", amount: money(120_000), due_day: 10)
    transition = apply(:fixed_costs, draft, Input::Items.new([item]))

    assert_equal :fixed_costs, transition.step
    assert_equal 1, transition.draft.fixed_costs.size

    transition = apply(:fixed_costs, transition.draft, command(:done))

    assert_equal :subscriptions, transition.step
  end

  def test_cancel_from_any_step
    transition = apply(:budgets, with_budgets.draft, command(:cancel))

    assert transition.cancelled?
  end

  def test_confirm_completes
    transition = apply(:confirm, with_budgets.draft, command(:confirm))

    assert transition.completed?
  end

  def test_restart_goes_back_to_an_empty_draft
    transition = apply(:confirm, with_budgets.draft, command(:restart))

    assert_equal :income_type, transition.step
    assert_nil transition.draft.salary
  end

  def test_draft_is_immutable_across_transitions
    draft = Draft.new(salary: money(500_000))
    apply(:categories, draft, command(:preset))

    assert_empty draft.categories
  end
end
