# frozen_string_literal: true

module Features
  module Budgets
    class Handler < Shared::Handler
      # "/budget mercado 500", "/budget lazer 10%" ou "/budget extras livre".
      SET = %r{\A/budgets?\s+(.+?)\s+(\d[\d.,]*\s*%|[\d.,]+|livre|nenhum|sem\s+limite)\s*\z}i
      NO_LIMIT = /\A(livre|nenhum|sem\s+limite)\z/i
      PERCENT = /\A(\d+)\s*%\z/

      route SET, to: :set
      route(%r{\A/budgets?\z}i, to: :list)
      # "/budget mercado" sem valor: sem esta rota a mensagem cairia no
      # lançamento de gasto e viraria um gasto chamado "budget mercado".
      route(%r{\A/budgets?\s+.+\z}i, to: :incomplete)
      route "/orcamento", to: :list
      route "/orçamento", to: :list

      def initialize(view_budgets:, set_budget:, presenter:)
        @view_budgets = view_budgets
        @set_budget = set_budget
        @presenter = presenter
      end

      def list(request) = @presenter.call(@view_budgets.call(user_id: request.user_id))

      def incomplete(_request) = @presenter.call(Result.new(status: :invalid_limit))

      def set(request, hint, value)
        @presenter.call(@set_budget.call(user_id: request.user_id, hint: hint, limit: limit_for(value)))
      end

      private

      # Percentual é sobre o líquido, e o domínio recusa mais de 100.
      def limit_for(value)
        return Domain::BudgetLimit.none if value.match?(NO_LIMIT)

        percent = PERCENT.match(value)
        return percent_limit(percent[1].to_i) if percent

        money = Interface::MoneyParser.parse(value)
        money&.positive? ? Domain::BudgetLimit.fixed(money) : nil
      end

      def percent_limit(value)
        value.positive? && value <= 100 ? Domain::BudgetLimit.percent(value) : nil
      end
    end
  end
end
