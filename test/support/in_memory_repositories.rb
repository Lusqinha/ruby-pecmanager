# frozen_string_literal: true

# In-memory implementations of the repository ports. The whole point of the
# ports: use cases and controllers get tested without SQLite.
module InMemory
  class Base
    def initialize = @rows = {}

    attr_reader :rows

    def next_id = (@rows.keys.max || 0) + 1
  end

  class UserRepository < Base
    def find(id) = rows[id]

    def save(user)
      rows[user.id] = user
    end
  end

  class CategoryRepository < Base
    def for_user(user_id) = rows.values.select { |category| category.user_id == user_id }

    def find(user_id, id)
      category = rows[id]
      category if category&.user_id == user_id
    end

    def save(category)
      stored = build(category, category.user_id, category.id)
      rows[stored.id] = stored
    end

    def replace_all(user_id, categories, keep_ids: [])
      existing = for_user(user_id)
      existing.each do |category|
        next if categories.any? { |item| item.name.casecmp?(category.name) }
        next if keep_ids.include?(category.id)

        rows.delete(category.id)
      end

      categories.each do |category|
        match = existing.find { |item| item.name.casecmp?(category.name) }
        stored = build(category, user_id, match&.id || next_id, keywords: match&.keywords || category.keywords)
        rows[stored.id] = stored
      end
      for_user(user_id)
    end

    private

    def build(category, user_id, id, keywords: category.keywords)
      Domain::Category.new(id: id, user_id: user_id, name: category.name,
                           keywords: keywords, limit: category.limit)
    end
  end

  class ExpenseRepository < Base
    def add(expense)
      stored = clone_with(expense, next_id)
      rows[stored.id] = stored
    end

    def save(expense)
      rows[expense.id] = expense
    end

    def find(user_id, id)
      expense = rows[id]
      expense if expense&.user_id == user_id
    end

    def delete(user_id, id)
      rows.delete(id) if find(user_id, id)
    end

    def last_for(user_id) = for_user(user_id).max_by(&:id)

    def for_period(user_id, range)
      for_user(user_id).select { |expense| range.cover?(expense.spent_on) }.sort_by(&:id)
    end

    def for_category(user_id, category_id, range)
      for_period(user_id, range).select { |expense| expense.category_id == category_id }
    end

    def totals_by_category(user_id, range)
      for_period(user_id, range).group_by(&:category_id).transform_values do |expenses|
        expenses.reduce(Domain::Money.zero) { |total, expense| total + expense.amount }
      end
    end

    def category_ids_with_expenses(user_id) = for_user(user_id).filter_map(&:category_id).uniq

    private

    def for_user(user_id) = rows.values.select { |expense| expense.user_id == user_id }

    def clone_with(expense, id)
      Domain::Expense.new(id: id, user_id: expense.user_id, category_id: expense.category_id,
                          amount: expense.amount, description: expense.description,
                          spent_on: expense.spent_on, source: expense.source, created_at: expense.created_at)
    end
  end

  class CollectionRepository < Base
    def for_user(user_id) = rows.fetch(user_id, [])

    def replace_all(user_id, items)
      rows[user_id] = items.each_with_index.map { |item, index| with_id(item, user_id, index + 1) }
    end

    private

    def with_id(item, user_id, id)
      klass = item.class
      attrs = { id: id, user_id: user_id, name: item.name }
      case item
      when Domain::FixedCost then klass.new(**attrs, amount: item.amount, due_day: item.due_day,
                                            kind: item.kind, deduction: item.deduction?)
      when Domain::Subscription then klass.new(**attrs, amount: item.amount, due_day: item.due_day, cycle: item.cycle)
      else klass.new(**attrs, target: item.target, saved: item.saved, deadline: item.deadline)
      end
    end
  end

  class DraftRepository < Base
    def find(user_id) = rows[user_id]

    def save(user_id, step, draft)
      rows[user_id] = { step: step, draft: draft }
    end

    def delete(user_id) = rows.delete(user_id)
  end

  class InstallmentPlanRepository < Base
    def for_user(user_id) = rows.values.select { |plan| plan.user_id == user_id }.sort_by(&:id)

    def active(user_id, month) = for_user(user_id).select { |plan| plan.active_in?(month) }

    def find(user_id, id)
      plan = rows[id]
      plan if plan&.user_id == user_id
    end

    def add(plan)
      rows[next_id] = with_id(plan, next_id)
    end

    def save(plan)
      rows[plan.id] = plan
    end

    private

    def with_id(plan, id)
      Domain::InstallmentPlan.new(
        id: id, user_id: plan.user_id, category_id: plan.category_id, description: plan.description,
        origin: plan.origin, total: plan.total, count: plan.count, first_month: plan.first_month,
        cancelled_on: plan.cancelled_on, created_at: plan.created_at
      )
    end
  end

  # Container-shaped bundle wired to the in-memory repositories: same slices,
  # same router, no database.
  class Factory
    attr_reader :users, :categories, :expenses, :fixed_costs, :subscriptions, :goals, :drafts,
                :installment_plans, :clock
    attr_accessor :parser

    def initialize(clock:, parser:)
      @clock = clock
      @parser = parser
      @users = UserRepository.new
      @categories = CategoryRepository.new
      @expenses = ExpenseRepository.new
      @fixed_costs = CollectionRepository.new
      @subscriptions = CollectionRepository.new
      @goals = CollectionRepository.new
      @drafts = DraftRepository.new
      @installment_plans = InstallmentPlanRepository.new
    end

    def router
      Config::Router.new(handlers: [setup_handler, reports_handler, help_handler,
                                    installments_handler, expense_handler])
    end

    def setup_handler
      Features::Setup::Handler.new(
        find_user: find_user,
        start_setup: Features::Setup::StartSetup.new(draft_repository: drafts),
        advance_setup: Features::Setup::AdvanceSetup.new(
          draft_repository: drafts, complete_setup: complete_setup,
          input_parser: Features::Setup::InputParser.new, clock: clock
        ),
        presenter: Features::Setup::Presenter.new
      )
    end

    def installments_handler
      Features::Installments::Handler.new(
        record_installment: Features::Installments::RecordInstallment.new(
          category_repository: categories, installment_repository: installment_plans,
          parser: ParserProxy.new(self), clock: clock
        ),
        cancel_installment: Features::Installments::CancelInstallment.new(
          installment_repository: installment_plans, clock: clock
        ),
        view_installments: Features::Installments::ViewInstallments.new(
          installment_repository: installment_plans, clock: clock
        ),
        presenter: Features::Installments::Presenter.new
      )
    end

    def expense_handler
      Features::Expense::Handler.new(
        record_expense: Features::Expense::RecordExpense.new(
          user_repository: users, category_repository: categories,
          expense_repository: expenses, fixed_cost_repository: fixed_costs,
          parser: ParserProxy.new(self), clock: clock
        ),
        assign_category: Features::Expense::AssignCategory.new(
          user_repository: users, category_repository: categories, expense_repository: expenses,
          fixed_cost_repository: fixed_costs
        ),
        prepare_category_change: Features::Expense::PrepareCategoryChange.new(
          category_repository: categories, expense_repository: expenses
        ),
        undo_expense: Features::Expense::UndoExpense.new(expense_repository: expenses, clock: clock),
        presenter: Features::Expense::Presenter.new
      )
    end

    def view_projection
      view_projection ||= Features::Reports::ViewProjection.new(
        plan_assembler: plan_assembler, installment_repository: installment_plans, clock: clock
      )
    end

    def reports_handler

      Features::Reports::Handler.new(
        daily: Features::Reports::ViewDaily.new(expense_repository: expenses, category_repository: categories, clock: clock),
        monthly: Features::Reports::ViewMonthly.new(plan_assembler: plan_assembler, expense_repository: expenses, installment_repository: installment_plans, clock: clock),
        category: Features::Reports::ViewCategory.new(plan_assembler: plan_assembler, expense_repository: expenses, clock: clock),
        goals: Features::Reports::ViewGoals.new(goal_repository: goals, clock: clock),
        projection: view_projection,
        presenter: Features::Reports::Presenter.new
      )
    end

    def help_handler = Features::Help::Handler.new(presenter: Features::Help::Presenter.new)

    def find_user = Shared::FindUser.new(user_repository: users, draft_repository: drafts)

    def complete_setup
      Features::Setup::CompleteSetup.new(
        user_repository: users, category_repository: categories, fixed_cost_repository: fixed_costs,
        subscription_repository: subscriptions, goal_repository: goals,
        expense_repository: expenses, clock: clock
      )
    end

    def plan_assembler
      Features::Reports::PlanAssembler.new(
        user_repository: users, category_repository: categories, fixed_cost_repository: fixed_costs,
        subscription_repository: subscriptions, goal_repository: goals
      )
    end

    # Seeds a user that already finished setup.
    def seed_user(id: 3, salary_cents: 500_000, categories: [["Mercado", %w[mercado feira]], ["Transporte", %w[uber]]])
      users.save(Domain::User.new(id: id, name: "Lucas", salary: Domain::Money.new(salary_cents), setup_done_at: clock.now))
      entities = categories.each_with_index.map do |(name, keywords), index|
        Domain::Category.new(name: name, keywords: keywords,
                             limit: Domain::BudgetLimit.fixed(Domain::Money.new((index + 1) * 50_000)))
      end
      self.categories.replace_all(id, entities)
      users.find(id)
    end
  end

  # Lets a test swap the parser after the handlers are built.
  class ParserProxy
    def initialize(factory) = @factory = factory
    def parse(text, today: nil, categories: []) = @factory.parser.parse(text, today: today, categories: categories)
  end
end
