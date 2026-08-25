# frozen_string_literal: true

module Features
  module Reports
    # Aritmética pura: renda líquida menos parcelas, tetos e custos fixos, mês a
    # mês, com o acumulado dizendo quando cada meta fecha. Nenhum modelo é
    # consultado aqui — e não deve ser.
    class ViewProjection
      MINIMUM_MONTHS = 3
      MAXIMUM_MONTHS = 24

      def initialize(plan_assembler:, installment_repository:, clock:)
        @plan_assembler = plan_assembler
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:)
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        plans = @installment_repository.for_user(user_id)
        lines = build_lines(plan, plans)

        ProjectionReport.new(net_income: plan.net_income, lines: lines, goals: goals(plan, lines))
      end

      private

      def build_lines(plan, plans)
        budgets = total(plan.categories) { |category| category.budget_for(plan.salary) }
        fixed = plan.living_costs + total(plan.subscriptions, &:monthly_amount)
        accumulated = Domain::Money.zero

        months(plans).map do |month|
          installments = total(plans) { |item| item.due_in(month) || Domain::Money.zero }
          leftover = plan.net_income - installments - budgets - fixed
          accumulated += leftover

          ProjectionLine.new(month: month, installments: installments, budgets: budgets,
                             fixed: fixed, leftover: leftover, accumulated: accumulated)
        end
      end

      # O horizonte é a última parcela viva, com piso pra sempre mostrar algo e
      # teto pra caber numa mensagem de chat.
      def months(plans)
        first = Domain::Month.first_of(@clock.today)
        last = plans.reject(&:cancelled?).map(&:last_month).max
        count = last ? Domain::Month.distance(first, last) + 1 : MINIMUM_MONTHS

        (0...count.clamp(MINIMUM_MONTHS, MAXIMUM_MONTHS)).map { |index| Domain::Month.advance(first, index) }
      end

      def goals(plan, lines)
        plan.goals.map do |goal|
          covered = lines.find { |line| line.accumulated >= goal.missing }
          ProjectionGoal.new(name: goal.name, target: goal.target, covered_on: covered&.month)
        end
      end

      def total(items)
        items.reduce(Domain::Money.zero) { |sum, item| sum + yield(item) }
      end
    end
  end
end
