# frozen_string_literal: true

# O boot carrega a slice em ordem alfabética e as rotas abaixo precisam do
# módulo já definido.
require_relative "payload"

module Features
  module Imports
    class Handler < Shared::Handler
      # Texto que começa com "{" é JSON colado: não precisa vir depois do
      # comando, e o próprio conteúdo diz se é gasto ou parcelamento.
      JSON_TEXT = /\A\s*\{/

      route "/importar_parcelas", to: :explain_installments
      route "/importar_gastos", to: :explain_expenses
      route "/importar", to: :explain_menu
      route JSON_TEXT, to: :receive
      callback(/\Aimport:(ok|no|budget|free)\z/, to: :decide)

      def initialize(prepare_import:, confirm_import:, category_repository:, pending_repository:, presenter:)
        @prepare_import = prepare_import
        @confirm_import = confirm_import
        @category_repository = category_repository
        @pending_repository = pending_repository
        @presenter = presenter
      end

      def explain_installments(request) = explain(request, :installments)
      def explain_expenses(request) = explain(request, :expenses)

      def explain_menu(_request)
        Interface::ViewMessage.text(
          "Dois imports, cada um com seu formato:\n" \
          "/importar_parcelas — compras parceladas do cartão\n" \
          "/importar_gastos — lançamentos avulsos"
        )
      end

      # O tipo sai do conteúdo, então o mesmo caminho serve pros dois comandos.
      def receive(request)
        kind = Payload.parse(request.text).kind
        @presenter.call(@prepare_import.call(user_id: request.user_id, text: request.text, kind: kind))
      end

      DECISIONS = { "ok" => nil, "budget" => true, "free" => false }.freeze

      def decide(request, choice)
        return confirm(request, DECISIONS[choice]) if DECISIONS.key?(choice)

        @pending_repository.delete(request.user_id)
        @presenter.call(Result.new(status: :discarded))
      end

      private

      def explain(request, kind)
        @presenter.instructions(kind, @category_repository.for_user(request.user_id))
      end

      def confirm(request, in_budget)
        @presenter.call(@confirm_import.call(user_id: request.user_id, in_budget: in_budget))
      end
    end
  end
end
