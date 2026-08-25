# frozen_string_literal: true

module Features
  module Budgets
    class ViewBudgets
      def initialize(plan_assembler:, clock:)
        @plan_assembler = plan_assembler
        @clock = clock
      end

      def call(user_id:)
        user, plan = @plan_assembler.call(user_id: user_id)
        return Result.new(status: :no_plan) unless user

        Result.new(status: :listed, month: @clock.today, lines: lines(plan),
                   summary: plan.summary(@clock.today), net_income: plan.net_income)
      end

      private

      def lines(plan)
        plan.categories.map do |category|
          BudgetLine.new(category_name: category.name, limit: category.limit,
                         amount: category.budget_for(plan.net_income))
        end
      end
    end

    # Mexer num teto muda o quanto sobra para todos os outros, então a resposta
    # sempre volta com o plano inteiro recalculado.
    class SetBudget
      def initialize(plan_assembler:, category_repository:, clock:)
        @plan_assembler = plan_assembler
        @category_repository = category_repository
        @clock = clock
      end

      def call(user_id:, hint:, limit:)
        user, plan = @plan_assembler.call(user_id: user_id)
        return Result.new(status: :no_plan) unless user

        category = Domain::Categorizer.resolve(plan.categories, hint)
        return Result.new(status: :unknown_category, names: plan.categories.map(&:name)) unless category
        return Result.new(status: :invalid_limit) unless limit

        previous = category.budget_for(plan.net_income)
        @category_repository.save(category.with_limit(limit))

        updated(user_id, category.name, previous)
      end

      private

      def updated(user_id, name, previous)
        result = ViewBudgets.new(plan_assembler: @plan_assembler, clock: @clock).call(user_id: user_id)
        result.status = :updated
        result.category_name = name
        result.previous = previous
        result
      end
    end
  end
end
