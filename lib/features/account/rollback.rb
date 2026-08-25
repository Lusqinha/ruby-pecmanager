# frozen_string_literal: true

module Features
  module Account
    # Reverte o que foi criado numa janela de minutos. Só gastos e planos: são
    # os únicos que carregam created_at, e são o que um import errado despeja de
    # uma vez.
    class PreviewRollback
      MAX_MINUTES = 60 * 24 * 7

      def initialize(expense_repository:, installment_repository:, clock:)
        @expense_repository = expense_repository
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:, minutes:)
        minutes = minutes.to_i
        return RollbackResult.new(status: :invalid) unless minutes.positive? && minutes <= MAX_MINUTES

        since = @clock.now - (minutes * 60)
        RollbackResult.new(status: :preview, minutes: minutes, since: since,
                           expenses: @expense_repository.created_since(user_id, since),
                           plans: @installment_repository.created_since(user_id, since))
      end
    end

    class ApplyRollback
      def initialize(expense_repository:, installment_repository:)
        @expense_repository = expense_repository
        @installment_repository = installment_repository
      end

      # A janela é congelada no preview: o botão carrega o instante, não os
      # minutos, senão a janela deslizaria entre ver e confirmar.
      def call(user_id:, since:)
        expenses = @expense_repository.created_since(user_id, since)
        plans = @installment_repository.created_since(user_id, since)

        expenses.each { |expense| @expense_repository.delete(user_id, expense.id) }
        plans.each { |plan| @installment_repository.delete(user_id, plan.id) }

        RollbackResult.new(status: :applied, since: since, expenses: expenses, plans: plans)
      end
    end
  end
end
