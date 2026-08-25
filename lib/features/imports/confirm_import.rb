# frozen_string_literal: true

module Features
  module Imports
    # Grava o lote guardado. A categoria sai do Categorizer; o que não resolver
    # entra sem categoria e vira pergunta depois, como qualquer lançamento.
    class ConfirmImport
      def initialize(category_repository:, installment_repository:, expense_repository:, user_repository:,
                     pending_repository:, clock:)
        @user_repository = user_repository
        @category_repository = category_repository
        @installment_repository = installment_repository
        @expense_repository = expense_repository
        @pending_repository = pending_repository
        @clock = clock
      end

      # in_budget vem da pergunta feita no preview do lote de parcelamentos:
      # fora do budget a parcela não entra em linha de categoria nenhuma, então
      # nem se tenta categorizar.
      def call(user_id:, in_budget: nil)
        stored = @pending_repository.find(user_id)
        return Result.new(status: :nothing_pending) unless stored

        payload = Payload.parse(stored)
        return Result.new(status: :invalid, error: payload.error) if payload.error

        remember(user_id, in_budget)
        categories = categorize?(payload, in_budget) ? @category_repository.for_user(user_id) : []
        recorded = payload.items.map { |item| record(user_id, item, payload.source, categories) }
        @pending_repository.delete(user_id)

        Result.new(status: :recorded, kind: payload.kind, recorded: recorded.size,
                   uncategorized: categories.empty? ? 0 : recorded.count(&:nil?),
                   in_budget: in_budget)
      end

      private

      def categorize?(payload, in_budget) = payload.kind == :expenses || in_budget

      # A resposta do lote vale daqui pra frente: é a mesma regra que o /mes e a
      # projeção usam pra todas as parcelas.
      def remember(user_id, in_budget)
        return if in_budget.nil?

        user = @user_repository.find(user_id)
        @user_repository.save(user.with_installments_in_budget(in_budget)) if user
      end

      def record(user_id, item, source, categories)
        category = categories.empty? ? nil : (Domain::Categorizer.resolve(categories, item.description) ||
                   Domain::Categorizer.resolve(categories, item.category_hint))
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
