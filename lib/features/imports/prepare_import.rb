# frozen_string_literal: true

module Features
  module Imports
    # Lê o JSON, separa o que já existe e guarda o lote esperando confirmação.
    # Nada é gravado aqui.
    class PrepareImport
      def initialize(installment_repository:, expense_repository:, pending_repository:)
        @installment_repository = installment_repository
        @expense_repository = expense_repository
        @pending_repository = pending_repository
      end

      def call(user_id:, text:, kind:)
        payload = Payload.parse(text)
        return Result.new(status: :invalid, error: payload.error) if payload.error
        return Result.new(status: :invalid, error: :wrong_kind, kind: payload.kind) unless payload.kind == kind

        fresh, duplicates = payload.items.partition { |item| !duplicate?(user_id, item) }
        return Result.new(status: :all_duplicated, kind: kind, duplicates: duplicates) if fresh.empty?

        @pending_repository.save(user_id, dump(payload, fresh))
        Result.new(status: :prepared, kind: kind, items: fresh, duplicates: duplicates, source: payload.source)
      end

      private

      # Parcelamento: o mês inicial calculado é estável entre faturas, então
      # descrição + valor + mês inicial identificam o plano sem heurística.
      # Gasto: mesma descrição, valor e dia.
      def duplicate?(user_id, item)
        return duplicate_plan?(user_id, item) if item.installment?

        @expense_repository.for_period(user_id, item.date..item.date).any? do |expense|
          expense.amount == item.amount && same?(expense.description, item.description)
        end
      end

      def duplicate_plan?(user_id, item)
        @installment_repository.for_user(user_id).any? do |plan|
          plan.first_month == item.first_month && plan.total == item.total && same?(plan.description, item.description)
        end
      end

      def same?(one, other) = Domain::Categorizer.normalize(one) == Domain::Categorizer.normalize(other)

      # O que fica guardado é o mesmo formato que o usuário manda: o Payload
      # relê isto na confirmação, então valor tem de continuar em reais.
      def dump(payload, items)
        JSON.generate(
          fonte: payload.source,
          lancamentos: items.map do |item|
            line = { data: item.date.iso8601, descricao: item.description, valor: reais(item.amount),
                     categoria: item.category_hint }.compact
            item.installment? ? line.merge(parcela: item.number, parcelas: item.count) : line
          end
        )
      end

      def reais(money) = format("%d,%02d", money.cents / 100, money.cents % 100)
    end
  end
end
