# frozen_string_literal: true

module Features
  module Installments
    class CancelInstallment
      def initialize(installment_repository:, clock:)
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:, plan_id:)
        plan = @installment_repository.find(user_id, plan_id)
        return Result.new(status: :missing) unless plan

        today = @clock.today
        remaining = cut_count(plan, today)
        cancelled = @installment_repository.save(plan.cancel(on: today))

        Result.new(status: :cancelled, plan: cancelled, month: today, cancelled_count: remaining)
      end

      private

      # Plano em curso perde o que vem depois deste mês; plano que ainda não
      # começou perde tudo; plano terminado não perde nada.
      def cut_count(plan, today)
        return plan.count - plan.number_in(today) if plan.number_in(today)

        Domain::Month.first_of(today) < plan.first_month ? plan.count : 0
      end
    end
  end
end
