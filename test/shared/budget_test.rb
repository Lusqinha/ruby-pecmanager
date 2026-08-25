# frozen_string_literal: true

require_relative "../test_helper"

class BudgetLimitTest < Minitest::Test
  def test_percentage_limit_follows_the_salary
    assert_equal 75_000, Domain::BudgetLimit.percent(15).cents_for(money(500_000)).cents
  end

  def test_fixed_limit_ignores_the_salary
    assert_equal 30_000, Domain::BudgetLimit.fixed(money(30_000)).cents_for(money(500_000)).cents
  end

  def test_no_limit_is_zero
    assert Domain::BudgetLimit.none.none?
    assert_equal 0, Domain::BudgetLimit.none.cents_for(money(500_000)).cents
  end
end

class FinancialPlanTest < Minitest::Test
  def plan(categories: [], fixed_costs: [], subscriptions: [], goals: [])
    Domain::FinancialPlan.new(salary: money(500_000), categories: categories, fixed_costs: fixed_costs,
                              subscriptions: subscriptions, goals: goals)
  end

  def category(limit) = Domain::Category.new(name: "X", limit: limit)

  def test_yearly_subscription_counts_as_one_twelfth
    subscription = Domain::Subscription.new(name: "dominio", amount: money(12_000), cycle: Domain::Subscription::YEARLY)
    summary = plan(subscriptions: [subscription]).summary(TODAY)

    assert_equal 1_000, summary.subscriptions.cents
  end

  def test_goal_without_deadline_requires_nothing_monthly
    goal = Domain::Goal.new(name: "reserva", target: money(1_000_000))

    assert_equal 0, plan(goals: [goal]).summary(TODAY).goals.cents
  end

  def test_goal_with_deadline_spreads_over_the_remaining_months
    goal = Domain::Goal.new(name: "reserva", target: money(1_000_000), deadline: Date.new(2027, 8, 1))

    assert_equal 83_334, plan(goals: [goal]).summary(TODAY).goals.cents # 12 months
  end

  def test_available_is_salary_minus_commitments
    summary = plan(
      fixed_costs: [Domain::FixedCost.new(name: "aluguel", amount: money(150_000))],
      subscriptions: [Domain::Subscription.new(name: "netflix", amount: money(4_000))]
    ).summary(TODAY)

    assert_equal 346_000, summary.available.cents
  end

  def test_subscriptions_with_their_own_category_are_not_charged_twice
    plan = plan(categories: [Domain::Category.new(name: "Assinaturas", limit: Domain::BudgetLimit.fixed(money(20_000)))],
                subscriptions: [Domain::Subscription.new(name: "netflix", amount: money(4_000))])
    summary = plan.summary(TODAY)

    assert summary.subscriptions_in_budget?
    assert_equal 4_000, summary.subscriptions.cents
    assert_equal 500_000, summary.available.cents
    assert_equal 480_000, summary.free.cents
  end

  def test_a_subscription_counts_as_spending_in_its_category
    subscription = Domain::Subscription.new(name: "netflix", amount: money(4_000))
    subscriptions_category = Domain::Category.new(id: 1, name: "Assinaturas")
    other = Domain::Category.new(id: 2, name: "Mercado")
    plan = plan(categories: [subscriptions_category, other], subscriptions: [subscription])

    assert_equal 5_000, plan.spent_for(subscriptions_category, { 1 => money(1_000) }).cents
    assert_equal 1_000, plan.spent_for(other, { 2 => money(1_000) }).cents
  end

  def test_flags_budgets_that_exceed_what_is_left
    summary = plan(
      categories: Array.new(7) { category(Domain::BudgetLimit.percent(20)) },
      fixed_costs: [Domain::FixedCost.new(name: "aluguel", amount: money(150_000))]
    ).summary(TODAY)

    assert summary.over?
    assert_equal 350_000, summary.over.cents # committed 700k vs available 350k
  end

  def test_does_not_flag_a_plan_that_fits
    summary = plan(categories: Array.new(7) { category(Domain::BudgetLimit.percent(5)) }).summary(TODAY)

    refute summary.over?
  end
end
