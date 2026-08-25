# frozen_string_literal: true

module Features
  module Installments
    class ViewInstallments
      def initialize(installment_repository:, clock:)
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:)
        month = @clock.today
        Result.new(status: :listed, plans: @installment_repository.active(user_id, month), month: month)
      end
    end
  end
end
