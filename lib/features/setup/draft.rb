# frozen_string_literal: true

module Features
  module Setup
    # Immutable: every change returns a new draft, which keeps the wizard a pure
    # function of (step, draft, input).
    class Draft
      attr_reader :income_type, :salary, :categories, :budget_index, :deductions, :fixed_costs,
                  :subscriptions, :goals

      # income_type muda só o que o wizard pergunta: PJ desconta imposto e INSS
      # da receita, CLT já recebe líquido e informa o que quiser à mão.
      def initialize(income_type: nil, salary: nil, categories: [], budget_index: 0, deductions: [],
                     fixed_costs: [], subscriptions: [], goals: [])
        @income_type = income_type
        @deductions = deductions
        @salary = salary
        @categories = categories
        @budget_index = budget_index
        @fixed_costs = fixed_costs
        @subscriptions = subscriptions
        @goals = goals
        freeze
      end

      def with(**changes)
        self.class.new(
          income_type: changes.fetch(:income_type, income_type),
          deductions: changes.fetch(:deductions, deductions),
          salary: changes.fetch(:salary, salary),
          categories: changes.fetch(:categories, categories),
          budget_index: changes.fetch(:budget_index, budget_index),
          fixed_costs: changes.fetch(:fixed_costs, fixed_costs),
          subscriptions: changes.fetch(:subscriptions, subscriptions),
          goals: changes.fetch(:goals, goals)
        )
      end

      def current_category = categories[budget_index]

      def budgets_pending? = !current_category.nil?

      def with_budget(limit)
        updated = categories.dup
        updated[budget_index] = replace_limit(updated[budget_index], limit)
        with(categories: updated, budget_index: budget_index + 1)
      end

      def skipping_budget = with(budget_index: budget_index + 1)

      def rewind_budget = with(budget_index: [budget_index - 1, 0].max)

      # Coming back into the budget loop lands on the last category, not past it.
      def at_last_category = with(budget_index: [categories.size - 1, 0].max)

      def pj? = income_type == :pj

      # Deduções e custos fixos moram na mesma tabela: o que separa é a flag.
      def all_fixed_costs = deductions + fixed_costs

      def to_plan
        Domain::FinancialPlan.new(salary: salary || Domain::Money.zero, categories: categories,
                          fixed_costs: all_fixed_costs, subscriptions: subscriptions, goals: goals)
      end

      private

      def replace_limit(category, limit)
        Domain::Category.new(id: category.id, user_id: category.user_id, name: category.name,
                     keywords: category.keywords, limit: limit)
      end
    end
  end
end
