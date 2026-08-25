# frozen_string_literal: true

# O boot carrega a slice em ordem alfabética: a rota abaixo precisa do módulo já
# definido.
require_relative "text_input"

module Features
  module Installments
    class Handler < Shared::Handler
      route "/parcelas", to: :list
      # Texto com "12x" é parcelamento, não gasto: por isso esta slice entra no
      # router antes da de expense, que engoliria a mensagem no fallback.
      route TextInput, to: :record
      callback(/\Aplan:cancel:(\d+)\z/, to: :cancel)
      callback(/\Aplan:budget:(on|off)\z/, to: :toggle)

      def initialize(record_installment:, cancel_installment:, view_installments:, toggle_budget:, presenter:)
        @record_installment = record_installment
        @cancel_installment = cancel_installment
        @view_installments = view_installments
        @toggle_budget = toggle_budget
        @presenter = presenter
      end

      def toggle(request, choice)
        @presenter.call(@toggle_budget.call(user_id: request.user_id, enabled: choice == "on"))
      end

      def list(request) = @presenter.call(@view_installments.call(user_id: request.user_id))

      def record(request)
        @presenter.call(@record_installment.call(user_id: request.user_id, text: request.text))
      end

      def cancel(request, plan_id)
        @presenter.call(@cancel_installment.call(user_id: request.user_id, plan_id: plan_id.to_i))
      end
    end
  end
end
