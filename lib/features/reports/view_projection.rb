# frozen_string_literal: true

module Features
  module Reports
    # Aritmética pura: renda líquida menos parcelas, tetos e custos fixos, mês a
    # mês, com o acumulado dizendo quando cada meta fecha. Nenhum modelo é
    # consultado aqui — e não deve ser.
    class ViewProjection
      MINIMUM_MONTHS = 3
      MAXIMUM_MONTHS = 24
      FAR_FUTURE = Date.new(9999, 1, 1)

      def initialize(plan_assembler:, installment_repository:, clock:)
        @plan_assembler = plan_assembler
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:)
        user, plan = @plan_assembler.call(user_id: user_id)
        return nil unless user

        plans = @installment_repository.for_user(user_id)
        lines = build_lines(plan, plans, user.installments_in_budget?)

        ProjectionReport.new(
          net_income: plan.net_income, budgets: plan.committed, fixed: plan.living_costs,
          subscriptions: plan.subscriptions_total, subscriptions_in_budget: plan.subscriptions_in_budget?,
          installments_in_budget: user.installments_in_budget?,
          lines: lines, goals: goals(plan, lines)
        )
      end

      private

      def build_lines(plan, plans, in_budget)
        accumulated = Domain::Money.zero

        months(plans, plan.goals).map do |month|
          installments = total(plans) { |item| item.due_in(month) || Domain::Money.zero }
          # Contando no budget, a parcela já está dentro do teto: subtrair de
          # novo tiraria o mesmo dinheiro duas vezes.
          leftover = plan.leftover(in_budget ? Domain::Money.zero : installments)
          accumulated += leftover

          ProjectionLine.new(month: month, installments: installments, budgets: plan.committed,
                             fixed: plan.living_costs, leftover: leftover, accumulated: accumulated)
        end
      end

      # O horizonte vai até a última parcela viva ou o prazo mais longo de
      # caixinha — o que vier depois —, com piso pra sempre mostrar algo e teto
      # pra caber numa mensagem de chat.
      def months(plans, goals)
        first = Domain::Month.first_of(@clock.today)
        last = [plans.reject(&:cancelled?).map(&:last_month).max,
                goals.reject { |goal| goal.missing.zero? }.filter_map(&:deadline).max].compact.max
        count = last ? Domain::Month.distance(first, last) + 1 : MINIMUM_MONTHS

        (0...count.clamp(MINIMUM_MONTHS, MAXIMUM_MONTHS)).map { |index| Domain::Month.advance(first, index) }
      end

      # As caixinhas dividem a mesma sobra: a segunda só fecha depois da
      # primeira, então o que falta vai somando na ordem dos prazos.
      def goals(plan, lines)
        today = @clock.today
        needed = Domain::Money.zero

        by_deadline(plan.goals).map do |goal|
          needed += goal.missing
          covered = lines.find { |line| line.accumulated >= needed }
          ProjectionGoal.new(name: goal.name, target: goal.target, saved: goal.saved, missing: goal.missing,
                             monthly: goal.monthly_contribution(today), deadline: goal.deadline,
                             covered_on: goal.missing.zero? ? nil : covered&.month)
        end
      end

      def by_deadline(goals) = goals.sort_by { |goal| goal.deadline || FAR_FUTURE }

      def total(items)
        items.reduce(Domain::Money.zero) { |sum, item| sum + yield(item) }
      end
    end
  end
end
