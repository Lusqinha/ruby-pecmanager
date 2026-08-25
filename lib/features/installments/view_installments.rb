# frozen_string_literal: true

module Features
  module Installments
    class ViewInstallments
      def initialize(installment_repository:, clock:, user_repository:)
        @installment_repository = installment_repository
        @user_repository = user_repository
        @clock = clock
      end

      def call(user_id:)
        month = @clock.today
        Result.new(status: :listed, plans: @installment_repository.active(user_id, month), month: month,
                   in_budget: @user_repository.find(user_id)&.installments_in_budget?)
      end
    end
  end
end
