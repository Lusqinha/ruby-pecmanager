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
        remaining = plan.count - (plan.number_in(today) || plan.count)
        cancelled = @installment_repository.save(plan.cancel(on: today))

        Result.new(status: :cancelled, plan: cancelled, month: today, cancelled_count: remaining)
      end
    end
  end
end
