# frozen_string_literal: true

module Features
  module Installments
    class ToggleBudget
      def initialize(user_repository:, installment_repository:, clock:)
        @user_repository = user_repository
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:, enabled:)
        user = @user_repository.find(user_id)
        return Result.new(status: :missing) unless user

        @user_repository.save(user.with_installments_in_budget(enabled))
        month = @clock.today
        Result.new(status: :toggled, plans: @installment_repository.active(user_id, month), month: month,
                   in_budget: enabled)
      end
    end
  end
end
