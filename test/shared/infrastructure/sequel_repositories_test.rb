# frozen_string_literal: true

require_relative "../../test_helper"

# The adapters are the only place that touches SQLite, so this is the only
# suite that needs a database.
class SequelRepositoriesTest < Minitest::Test
  Store = Infrastructure::Persistence::SequelStore

  def setup
    @db = Store::Database.connect(":memory:")
    @users = Store::UserRepository.new(@db)
    @categories = Store::CategoryRepository.new(@db)
    @expenses = Store::ExpenseRepository.new(@db)
    @fixed_costs = Store::FixedCostRepository.new(@db)
    @subscriptions = Store::SubscriptionRepository.new(@db)
    @goals = Store::GoalRepository.new(@db)
    @drafts = Store::DraftRepository.new(@db, serializer: Features::Setup::DraftSerializer)
    @plans = Store::InstallmentPlanRepository.new(@db)
    @users.save(Domain::User.new(id: 3, name: "Lucas", salary: money(500_000), setup_done_at: NOW))
  end

  def seed_categories
    @categories.replace_all(3, [
                              Domain::Category.new(name: "Mercado", keywords: %w[mercado feira],
                                                   limit: Domain::BudgetLimit.fixed(money(80_000))),
                              Domain::Category.new(name: "Transporte", keywords: %w[uber],
                                                   limit: Domain::BudgetLimit.percent(15))
                            ])
  end

  def add_expense(category_id:, cents: 3_500, spent_on: TODAY)
    @expenses.add(Domain::Expense.new(user_id: 3, category_id: category_id, amount: money(cents),
                                      description: "mercado", spent_on: spent_on, source: "regex", created_at: NOW))
  end

  def test_user_round_trip
    user = @users.find(3)

    assert_equal 500_000, user.salary.cents
    assert user.setup_done?
    assert_instance_of Domain::User, user
  end

  def test_user_save_updates_instead_of_duplicating
    @users.save(Domain::User.new(id: 3, name: "Lucas", salary: money(600_000), setup_done_at: NOW))

    assert_equal 600_000, @users.find(3).salary.cents
    assert_equal 1, @db[:users].count
  end

  def test_category_limits_survive_the_round_trip
    seed_categories
    mercado, transporte = @categories.for_user(3)

    assert mercado.limit.fixed?
    assert_equal 80_000, mercado.budget_for(money(500_000)).cents
    assert transporte.limit.percent?
    assert_equal 75_000, transporte.budget_for(money(500_000)).cents
    assert_includes mercado.keywords, "feira"
  end

  def test_replace_all_keeps_categories_listed_in_keep_ids
    seed_categories
    mercado = @categories.for_user(3).first
    add_expense(category_id: mercado.id)

    @categories.replace_all(3, [Domain::Category.new(name: "Lazer", limit: Domain::BudgetLimit.none)],
                            keep_ids: @expenses.category_ids_with_expenses(3))
    names = @categories.for_user(3).map(&:name)

    assert_includes names, "Lazer"
    assert_includes names, "Mercado"
    refute_includes names, "Transporte"
  end

  def test_replace_all_preserves_learned_keywords_of_surviving_categories
    seed_categories
    mercado = @categories.for_user(3).first
    @categories.save(mercado.with_keyword("hortifruti"))

    @categories.replace_all(3, [Domain::Category.new(name: "Mercado", keywords: %w[mercado])])

    assert_includes @categories.for_user(3).first.keywords, "hortifruti"
  end

  def test_expense_crud
    seed_categories
    category = @categories.for_user(3).first
    expense = add_expense(category_id: category.id)

    assert_equal expense.id, @expenses.find(3, expense.id).id
    assert_equal expense.id, @expenses.last_for(3).id
    assert_nil @expenses.find(4, expense.id) # scoped to the owner

    @expenses.delete(3, expense.id)

    assert_nil @expenses.find(3, expense.id)
  end

  def test_totals_by_category_within_the_month
    seed_categories
    mercado, transporte = @categories.for_user(3)
    add_expense(category_id: mercado.id, cents: 3_500)
    add_expense(category_id: mercado.id, cents: 1_500)
    add_expense(category_id: transporte.id, cents: 1_250)
    add_expense(category_id: mercado.id, cents: 9_900, spent_on: TODAY << 1)

    totals = @expenses.totals_by_category(3, Date.new(2026, 8, 1)..Date.new(2026, 8, 31))

    assert_equal 5_000, totals[mercado.id].cents
    assert_equal 1_250, totals[transporte.id].cents
  end

  def test_uncategorized_expenses_group_under_nil
    add_expense(category_id: nil, cents: 12_000)
    totals = @expenses.totals_by_category(3, Date.new(2026, 8, 1)..Date.new(2026, 8, 31))

    assert_equal 12_000, totals[nil].cents
  end

  def test_collections_round_trip
    @fixed_costs.replace_all(3, [Domain::FixedCost.new(name: "aluguel", amount: money(120_000), due_day: 10)])
    @subscriptions.replace_all(3, [Domain::Subscription.new(name: "dominio", amount: money(6_000),
                                                           cycle: Domain::Subscription::YEARLY)])
    @goals.replace_all(3, [Domain::Goal.new(name: "reserva", target: money(1_000_000),
                                            deadline: Date.new(2027, 12, 1))])

    assert_equal 10, @fixed_costs.for_user(3).first.due_day
    assert @subscriptions.for_user(3).first.yearly?
    assert_equal Date.new(2027, 12, 1), @goals.for_user(3).first.deadline
  end

  def test_replace_all_wipes_the_previous_collection
    @fixed_costs.replace_all(3, [Domain::FixedCost.new(name: "aluguel", amount: money(120_000))])
    @fixed_costs.replace_all(3, [Domain::FixedCost.new(name: "luz", amount: money(18_000))])

    assert_equal %w[luz], @fixed_costs.for_user(3).map(&:name)
  end

  def test_draft_survives_the_json_round_trip
    draft = Features::Setup::Draft.new(
      salary: money(500_000), budget_index: 2,
      categories: [Domain::Category.new(name: "Mercado", keywords: %w[feira], limit: Domain::BudgetLimit.percent(15)),
                   Domain::Category.new(name: "Lazer", limit: Domain::BudgetLimit.fixed(money(30_000)))],
      fixed_costs: [Domain::FixedCost.new(name: "aluguel", amount: money(120_000), due_day: 10)],
      subscriptions: [Domain::Subscription.new(name: "dominio", amount: money(6_000), cycle: Domain::Subscription::YEARLY)],
      goals: [Domain::Goal.new(name: "reserva", target: money(1_000_000), deadline: Date.new(2027, 12, 1))]
    )

    @drafts.save(3, :budgets, draft)
    stored = @drafts.find(3)
    revived = stored[:draft]

    assert_equal :budgets, stored[:step]
    assert_equal 500_000, revived.salary.cents
    assert_equal 2, revived.budget_index
    assert revived.categories.first.limit.percent?
    assert_equal 30_000, revived.categories.last.budget_for(money(500_000)).cents
    assert_equal 10, revived.fixed_costs.first.due_day
    assert revived.subscriptions.first.yearly?
    assert_equal Date.new(2027, 12, 1), revived.goals.first.deadline
  end

  def test_draft_delete
    @drafts.save(3, :salary, Features::Setup::Draft.new)
    @drafts.delete(3)

    assert_nil @drafts.find(3)
  end
  def test_stores_and_reads_back_an_installment_plan
    stored = @plans.add(Domain::InstallmentPlan.new(
                          user_id: 3, description: "Notebook", origin: "Nubank",
                          total: money(120_000), count: 12, first_month: Date.new(2026, 8, 1)
                        ))

    assert stored.id
    assert_equal "Nubank", stored.origin
    assert_equal 10_000, stored.amount_for(1).cents
    assert_equal [stored.id], @plans.active(3, Date.new(2027, 1, 1)).map(&:id)
    assert_empty @plans.active(3, Date.new(2027, 9, 1))
  end

  def test_cancelling_a_plan_survives_a_round_trip
    stored = @plans.add(Domain::InstallmentPlan.new(
                          user_id: 3, description: "Cadeira", total: money(90_000),
                          count: 6, first_month: Date.new(2026, 8, 1)
                        ))
    @plans.save(stored.cancel(on: Date.new(2026, 9, 10)))

    assert @plans.find(3, stored.id).cancelled?
    assert_empty @plans.active(3, Date.new(2026, 10, 1))
  end
end
