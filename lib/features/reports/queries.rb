# frozen_string_literal: true

module Features
  module Reports
    class ViewDaily
      def initialize(expense_repository:, category_repository:, clock:)
        @expense_repository = expense_repository
        @category_repository = category_repository
        @clock = clock
      end

      def call(user_id:)
        date = @clock.today
        categories = @category_repository.for_user(user_id).to_h { |category| [category.id, category.name] }
        expenses = @expense_repository.for_period(user_id, date..date)

        DailyReport.new(
          date: date,
          entries: expenses.map do |expense|
            DailyEntry.new(amount: expense.amount, description: expense.description,
                                category_name: categories[expense.category_id])
          end,
          total: expenses.reduce(Domain::Money.zero) { |total, expense| total + expense.amount }
        )
      end
    end

    class ViewMonthly
      def initialize(plan_assembler:, expense_repository:, installment_repository:, clock:, user_repository: nil)
        @user_repository = user_repository
        @plan_assembler = plan_assembler
        @expense_repository = expense_repository
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:)
        today = @clock.today
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        totals = @expense_repository.totals_by_category(user_id, Domain::Month.range(today))
        plans = @installment_repository.active(user_id, today)
        installment_lines = installment_lines(plans, today)
        committed = user.installments_in_budget? ? by_category(plans, today) : {}

        lines = plan.categories.map do |category|
          spent = (totals[category.id] || Domain::Money.zero) + (committed[category.id] || Domain::Money.zero)
          MonthlyLine.new(category_name: category.name, spent: spent,
                          limit: category.budget_for(plan.net_income))
        end.sort_by { |line| -line.spent.cents }

        MonthlyReport.new(
          month: today, lines: lines,
          uncategorized: totals[nil] || Domain::Money.zero,
          total: totals.values.reduce(Domain::Money.zero) { |sum, value| sum + value },
          summary: plan.summary(today),
          installment_lines: installment_lines,
          installments_total: installment_lines.reduce(Domain::Money.zero) { |sum, line| sum + line.amount }
        )
      end

      private

      def installment_lines(plans, today)
        plans.map do |plan|
          InstallmentLine.new(description: plan.description, label: plan.label_in(today),
                              amount: plan.due_in(today), origin: plan.origin)
        end
      end

      # Só quando a opção está ligada: a parcela vira gasto da categoria dela.
      def by_category(plans, today)
        plans.each_with_object({}) do |plan, totals|
          next unless plan.category_id

          totals[plan.category_id] = (totals[plan.category_id] || Domain::Money.zero) + plan.due_in(today)
        end
      end
    end

    class ViewCategory
      LIMIT = 10

      def initialize(plan_assembler:, expense_repository:, clock:)
        @plan_assembler = plan_assembler
        @expense_repository = expense_repository
        @clock = clock
      end

      def call(user_id:, hint:)
        today = @clock.today
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        category = Domain::Categorizer.resolve(plan.categories, hint)
        unless category
          return CategoryReport.new(status: :not_found, available_names: plan.categories.map(&:name))
        end

        expenses = @expense_repository.for_category(user_id, category.id, Domain::Month.range(today))
        CategoryReport.new(
          status: :found, category_name: category.name, month: today,
          spent: expenses.reduce(Domain::Money.zero) { |total, expense| total + expense.amount },
          limit: category.budget_for(plan.net_income),
          entries: expenses.sort_by { |expense| [-expense.spent_on.jd, -expense.id.to_i] }.first(LIMIT).map do |expense|
            CategoryEntry.new(date: expense.spent_on, amount: expense.amount, description: expense.description)
          end
        )
      end
    end

  end
end
