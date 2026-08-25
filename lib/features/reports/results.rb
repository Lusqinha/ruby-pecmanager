# frozen_string_literal: true

module Features
  module Reports
    DailyReport = Struct.new(:date, :entries, :total, keyword_init: true)
    DailyEntry = Struct.new(:amount, :description, :category_name, keyword_init: true)

    MonthlyReport = Struct.new(:month, :lines, :uncategorized, :total, :summary,
                               :installment_lines, :installments_total, keyword_init: true)
    # Parcela é bloco próprio: não consome teto de categoria, porque foi
    # decidida meses atrás e a projeção já a subtrai separadamente.
    InstallmentLine = Struct.new(:description, :label, :amount, :origin, keyword_init: true)
    MonthlyLine = Struct.new(:category_name, :spent, :limit, keyword_init: true)

    CategoryReport = Struct.new(:status, :category_name, :month, :spent, :limit, :entries, :available_names,
                                keyword_init: true) do
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

    ProjectionReport = Struct.new(:net_income, :lines, :goals, keyword_init: true)
    ProjectionLine = Struct.new(:month, :installments, :budgets, :fixed, :leftover, :accumulated,
                                keyword_init: true)
    ProjectionGoal = Struct.new(:name, :target, :covered_on, keyword_init: true)

  end
end
