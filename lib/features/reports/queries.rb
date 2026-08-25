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

      def call(user_id:, month: nil)
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        month = Domain::Month.first_of(month || @clock.today)
        current = month == Domain::Month.first_of(@clock.today)
        totals = @expense_repository.totals_by_category(user_id, Domain::Month.range(month))
        plans = @installment_repository.active(user_id, month)

        build(month, current, plan, user, totals, plans)
      end

      private

      def build(month, current, plan, user, totals, plans)
        lines = category_lines(plan, totals, plans, user, month)
        installments = installment_lines(plans, month)
        installments_total = installments.reduce(Domain::Money.zero) { |sum, line| sum + line.amount }
        summary = plan.summary(month)
        # A parcela dentro do teto já foi descontada com o budget.
        leftover = plan.leftover(user.installments_in_budget? ? Domain::Money.zero : installments_total)

        MonthlyReport.new(
          month: month, current: current, lines: lines,
          uncategorized: totals[nil] || Domain::Money.zero,
          # Assinatura dentro do teto de uma categoria é gasto do mês como
          # qualquer outro, mesmo sem lançamento.
          total: totals.values.reduce(Domain::Money.zero) { |sum, value| sum + value } +
                 (plan.subscriptions_in_budget? ? plan.subscriptions_total : Domain::Money.zero),
          summary: summary, leftover: leftover,
          installment_lines: installments, installments_total: installments_total,
          allocation: Domain::Allocation.of(leftover, plan.goals),
          moves: rebalance(current, summary, leftover, lines)
        )
      end

      def category_lines(plan, totals, plans, user, month)
        committed = user.installments_in_budget? ? by_category(plans, month) : {}

        plan.categories.map do |category|
          spent = plan.spent_for(category, totals) + (committed[category.id] || Domain::Money.zero)
          MonthlyLine.new(category_name: category.name, spent: spent,
                          limit: category.budget_for(plan.net_income))
        end.sort_by { |line| -line.spent.cents }
      end

      # Só no mês corrente: num mês futuro nada foi gasto ainda, e toda
      # categoria pareceria folgada.
      def rebalance(current, summary, leftover, lines)
        return [] unless current

        Domain::Rebalance.moves(summary.goals - leftover, slots(lines))
      end

      def slots(lines)
        lines.map { |line| Domain::Rebalance::Slot.new(name: line.category_name, limit: line.limit, spent: line.spent) }
      end

      def installment_lines(plans, month)
        plans.map do |plan|
          InstallmentLine.new(description: plan.description, label: plan.label_in(month),
                              amount: plan.due_in(month), origin: plan.origin)
        end
      end

      # Só quando a opção está ligada: a parcela vira gasto da categoria dela.
      def by_category(plans, month)
        plans.each_with_object({}) do |plan, totals|
          next unless plan.category_id

          totals[plan.category_id] = (totals[plan.category_id] || Domain::Money.zero) + plan.due_in(month)
        end
      end
    end

    # Fechamento da semana: o que saiu desde segunda e quanto resta de budget
    # para os dias que ainda faltam no mês.
    class ViewWeekly
      def initialize(plan_assembler:, expense_repository:, clock:)
        @plan_assembler = plan_assembler
        @expense_repository = expense_repository
        @clock = clock
      end

      def call(user_id:)
        today = @clock.today
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        week = week_range(today)
        days_left = days_left(today)
        month_totals = @expense_repository.totals_by_category(user_id, Domain::Month.range(today))
        week_totals = @expense_repository.totals_by_category(user_id, week)

        WeeklyReport.new(
          from: week.first, to: week.last, days_left: days_left,
          spent: total(week_totals),
          lines: lines(plan, month_totals, week_totals, days_left)
        )
      end

      private

      # Segunda até hoje: a semana corrente, não os últimos sete dias.
      def week_range(today) = (today - ((today.wday + 6) % 7))..today

      # Inclui hoje: sobrar "0 dia" só quando o mês virou.
      def days_left(today) = (Domain::Month.range(today).last - today).to_i + 1

      def lines(plan, month_totals, week_totals, days_left)
        plan.categories.map do |category|
          limit = category.budget_for(plan.net_income)
          spent = plan.spent_for(category, month_totals)
          WeeklyLine.new(category_name: category.name,
                         week: week_totals[category.id] || Domain::Money.zero,
                         spent: spent, limit: limit,
                         left: [limit - spent, Domain::Money.zero].max,
                         days_left: days_left)
        end.sort_by { |line| -line.week.cents }
      end

      def total(totals) = totals.values.reduce(Domain::Money.zero) { |sum, value| sum + value }
    end

    # Total gasto em cada um dos últimos meses, do mais antigo para o atual.
    class ViewHistory
      MONTHS = 6

      def initialize(expense_repository:, clock:)
        @expense_repository = expense_repository
        @clock = clock
      end

      def call(user_id:, months: MONTHS)
        first = Domain::Month.advance(@clock.today, -(months - 1))

        lines = (0...months).map do |index|
          month = Domain::Month.advance(first, index)
          expenses = @expense_repository.for_period(user_id, Domain::Month.range(month))
          HistoryLine.new(month: month,
                          total: expenses.reduce(Domain::Money.zero) { |sum, item| sum + item.amount })
        end

        HistoryReport.new(months: lines)
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
        booked = expenses.reduce(Domain::Money.zero) { |total, expense| total + expense.amount }
        subscriptions = plan.spent_for(category, {}) # zero fora da categoria de assinaturas
        CategoryReport.new(
          status: :found, category_name: category.name, month: today,
          spent: booked + subscriptions, subscriptions: subscriptions,
          limit: category.budget_for(plan.net_income),
          entries: expenses.sort_by { |expense| [-expense.spent_on.jd, -expense.id.to_i] }.first(LIMIT).map do |expense|
            CategoryEntry.new(date: expense.spent_on, amount: expense.amount, description: expense.description)
          end
        )
      end
    end

  end
end
