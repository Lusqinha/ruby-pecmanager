# frozen_string_literal: true

module Features
  module Setup
    # Intercepts instead of routing: mid-wizard, "35 mercado" is the answer to a
    # step, not an expense.
    class Handler < Shared::Handler
      route "/setup", to: :start

      def initialize(find_user:, start_setup:, advance_setup:, presenter:)
        @find_user = find_user
        @start_setup = start_setup
        @advance_setup = advance_setup
        @presenter = presenter
      end

      # Só estes botões pertencem ao wizard; qualquer outro callback que chegue
      # com o setup aberto é de uma tela antiga e não pode virar resposta —
      # "undo:1200" chegava a ser lido como salário de R$ 12,00.
      OWN_BUTTONS = %w[preset confirmar recomecar pj clt].freeze

      def intercept(request)
        status = @find_user.call(user_id: request.user_id)
        return advance(request, text: stale?(request) ? "" : request.text) if status[:setup_in_progress]
        return start(request) unless status[:user]&.setup_done?

        nil
      end

      def start(request)
        @presenter.call(@start_setup.call(user_id: request.user_id))
      end

      private

      def stale?(request) = request.callback? && !OWN_BUTTONS.include?(request.text.to_s)

      def advance(request, text: request.text)
        state = @advance_setup.call(user_id: request.user_id, text: text, name: request.name)
        state ? @presenter.call(state) : start(request)
      end
    end
  end
end
