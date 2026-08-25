# frozen_string_literal: true

module Features
  module Imports
    # Grava o lote guardado. A categoria sai do Categorizer; o que não resolver
    # entra sem categoria e vira pergunta depois, como qualquer lançamento.
    class ConfirmImport
      def initialize(category_repository:, installment_repository:, expense_repository:,
                     pending_repository:, clock:)
        @category_repository = category_repository
        @installment_repository = installment_repository
        @expense_repository = expense_repository
        @pending_repository = pending_repository
        @clock = clock
      end

      def call(user_id:)
        stored = @pending_repository.find(user_id)
        return Result.new(status: :nothing_pending) unless stored

        payload = Payload.parse(stored)
        return Result.new(status: :invalid, error: payload.error) if payload.error

        categories = @category_repository.for_user(user_id)
        recorded = payload.items.map { |item| record(user_id, item, payload.source, categories) }
        @pending_repository.delete(user_id)

        Result.new(status: :recorded, kind: payload.kind, recorded: recorded.size,
                   uncategorized: recorded.count(&:nil?))
      end

      private

      def record(user_id, item, source, categories)
        category = Domain::Categorizer.resolve(categories, item.description) ||
                   Domain::Categorizer.resolve(categories, item.category_hint)
        item.installment? ? add_plan(user_id, item, source, category) : add_expense(user_id, item, category)
        category
      end

      def add_plan(user_id, item, source, category)
        @installment_repository.add(
          Domain::InstallmentPlan.new(
            user_id: user_id, category_id: category&.id, description: item.description, origin: source,
            total: item.total, count: item.count, first_month: item.first_month
          )
        )
      end

      def add_expense(user_id, item, category)
        @expense_repository.add(
          Domain::Expense.new(user_id: user_id, category_id: category&.id, amount: item.amount,
                              description: item.description, spent_on: item.date,
                              source: "import", created_at: @clock.now)
        )
      end
    end
  end
end
