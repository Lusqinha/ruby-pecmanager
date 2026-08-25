# frozen_string_literal: true

module Features
  module Reports
    DailyReport = Struct.new(:date, :entries, :total, keyword_init: true)
    DailyEntry = Struct.new(:amount, :description, :category_name, keyword_init: true)

    MonthlyReport = Struct.new(:month, :current, :lines, :uncategorized, :total, :summary, :leftover,
                               :installment_lines, :installments_total, :allocation, :moves,
                               keyword_init: true) do
      def current? = !!current
      def previous_month = Domain::Month.advance(month, -1)
      def next_month = Domain::Month.advance(month, 1)
    end
    # Parcela é bloco próprio: não consome teto de categoria, porque foi
    # decidida meses atrás e a projeção já a subtrai separadamente.
    InstallmentLine = Struct.new(:description, :label, :amount, :origin, keyword_init: true)
    MonthlyLine = Struct.new(:category_name, :spent, :limit, keyword_init: true)

    CategoryReport = Struct.new(:status, :category_name, :month, :spent, :subscriptions, :limit, :entries,
                                :available_names, keyword_init: true) do
      def found? = status == :found
    end
    CategoryEntry = Struct.new(:date, :amount, :description, keyword_init: true)

    WeeklyReport = Struct.new(:from, :to, :spent, :days_left, :lines, keyword_init: true)
    WeeklyLine = Struct.new(:category_name, :week, :spent, :limit, :left, :days_left, keyword_init: true) do
      # Quanto dá pra gastar por dia com o que sobrou até o fim do mês.
      def per_day = days_left.positive? ? Domain::Money.new(left.cents / days_left) : left
      def over? = left.zero?
    end

    HistoryReport = Struct.new(:months, keyword_init: true)
    HistoryLine = Struct.new(:month, :total, keyword_init: true)

    ProjectionReport = Struct.new(:net_income, :budgets, :fixed, :subscriptions, :subscriptions_in_budget,
                                  :installments_in_budget, :lines, :goals, keyword_init: true) do
      def subscriptions_in_budget? = !!subscriptions_in_budget
      def installments_in_budget? = !!installments_in_budget
      def goals_monthly = goals.reduce(Domain::Money.zero) { |sum, goal| sum + goal.monthly }
      def accumulated = lines.last&.accumulated || Domain::Money.zero
      # A sobra do primeiro mês é a que o usuário tem na mão agora.
      def leftover = lines.first&.leftover || Domain::Money.zero
      def slack = leftover - goals_monthly
    end
    ProjectionLine = Struct.new(:month, :installments, :budgets, :fixed, :leftover, :accumulated,
                                keyword_init: true)
    ProjectionGoal = Struct.new(:name, :target, :saved, :missing, :monthly, :deadline, :covered_on,
                                keyword_init: true) do
      def done? = missing.zero?
    end

  end
end
