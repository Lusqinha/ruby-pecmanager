# frozen_string_literal: true

module Config
  # Composition root: the only place that knows every slice at once.
  class Container
    def initialize(db:, clock: Infrastructure::SystemClock.new, expense_parser: nil)
      @db = db
      @clock = clock
      # Só os testes passam um parser aqui; em produção é o adapter do registry.
      @expense_parser = expense_parser
    end

    # Order matters: setup intercepts while a wizard is open, and expense holds
    # the free-text fallback, so it answers last.
    def router
      @router ||= Router.new(handlers: [setup_handler, reports_handler, help_handler,
                                        installments_handler, expense_handler])
    end

    def setup_handler
      Features::Setup::Handler.new(
        find_user: find_user,
        start_setup: Features::Setup::StartSetup.new(draft_repository: drafts),
        advance_setup: Features::Setup::AdvanceSetup.new(
          draft_repository: drafts, complete_setup: complete_setup,
          input_parser: Features::Setup::InputParser.new, clock: @clock
        ),
        presenter: Features::Setup::Presenter.new
      )
    end

    def expense_handler
      Features::Expense::Handler.new(
        record_expense: Features::Expense::RecordExpense.new(
          user_repository: users, category_repository: categories,
          expense_repository: expenses, fixed_cost_repository: fixed_costs,
          parser: @expense_parser || llm_parser, clock: @clock
        ),
        assign_category: Features::Expense::AssignCategory.new(
          user_repository: users, category_repository: categories, expense_repository: expenses,
          fixed_cost_repository: fixed_costs
        ),
        prepare_category_change: Features::Expense::PrepareCategoryChange.new(
          category_repository: categories, expense_repository: expenses
        ),
        undo_expense: Features::Expense::UndoExpense.new(expense_repository: expenses, clock: @clock),
        presenter: Features::Expense::Presenter.new
      )
    end

    def installments_handler
      Features::Installments::Handler.new(
        record_installment: Features::Installments::RecordInstallment.new(
          category_repository: categories, installment_repository: installment_plans,
          parser: @expense_parser || llm_parser, clock: @clock
        ),
        cancel_installment: Features::Installments::CancelInstallment.new(
          installment_repository: installment_plans, clock: @clock
        ),
        view_installments: Features::Installments::ViewInstallments.new(
          installment_repository: installment_plans, clock: @clock
        ),
        presenter: Features::Installments::Presenter.new
      )
    end

    def view_projection
      @view_projection ||= Features::Reports::ViewProjection.new(
        plan_assembler: plan_assembler, installment_repository: installment_plans, clock: @clock
      )
    end

    def reports_handler

      Features::Reports::Handler.new(
        daily: Features::Reports::ViewDaily.new(expense_repository: expenses, category_repository: categories, clock: @clock),
        monthly: Features::Reports::ViewMonthly.new(plan_assembler: plan_assembler, expense_repository: expenses, installment_repository: installment_plans, clock: @clock),
        category: Features::Reports::ViewCategory.new(plan_assembler: plan_assembler, expense_repository: expenses, clock: @clock),
        goals: Features::Reports::ViewGoals.new(goal_repository: goals, clock: @clock),
        projection: view_projection,
        presenter: Features::Reports::Presenter.new
      )
    end

    def help_handler = Features::Help::Handler.new(presenter: Features::Help::Presenter.new)

    def find_user = Shared::FindUser.new(user_repository: users, draft_repository: drafts)

    def users = @users ||= store::UserRepository.new(@db)
    def categories = @categories ||= store::CategoryRepository.new(@db)
    def expenses = @expenses ||= store::ExpenseRepository.new(@db)
    def fixed_costs = @fixed_costs ||= store::FixedCostRepository.new(@db)
    def subscriptions = @subscriptions ||= store::SubscriptionRepository.new(@db)
    def goals = @goals ||= store::GoalRepository.new(@db)
    def installment_plans = @installment_plans ||= store::InstallmentPlanRepository.new(@db)
    def drafts = @drafts ||= store::DraftRepository.new(@db, serializer: Features::Setup::DraftSerializer)

    # The registry resolves LLM_BACKEND, so a new provider never touches this
    # file.
    def llm_parser
      @llm_parser ||= Infrastructure::Llm::Registry.build(ENV.fetch("LLM_BACKEND", "ollama"))
    end

    private

    def store = Infrastructure::Persistence::SequelStore

    def complete_setup
      Features::Setup::CompleteSetup.new(
        user_repository: users, category_repository: categories, fixed_cost_repository: fixed_costs,
        subscription_repository: subscriptions, goal_repository: goals,
        expense_repository: expenses, clock: @clock
      )
    end

    def plan_assembler
      @plan_assembler ||= Features::Reports::PlanAssembler.new(
        user_repository: users, category_repository: categories, fixed_cost_repository: fixed_costs,
        subscription_repository: subscriptions, goal_repository: goals
      )
    end
  end
end
