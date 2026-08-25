# frozen_string_literal: true

module Features
  module Savings
    class Handler < Shared::Handler
      # "/caixinha viagem 200" guarda; com valor negativo, retira.
      route(%r{\A/caixinha\s+(.+?)(?:\s+(-?[\d.,]+))?\s*\z}i, to: :deposit)
      route "/caixinhas", to: :list
      route "/metas", to: :list

      def initialize(deposit:, view_boxes:, presenter:)
        @deposit = deposit
        @view_boxes = view_boxes
        @presenter = presenter
      end

      def deposit(request, name, amount = nil)
        @presenter.call(@deposit.call(user_id: request.user_id, name: name, amount: money(amount)))
      end

      def list(request) = @presenter.call(@view_boxes.call(user_id: request.user_id))

      private

      def money(text)
        return nil if text.nil?

        parsed = Interface::MoneyParser.parse(text.delete("-"))
        return nil unless parsed

        text.start_with?("-") ? Domain::Money.zero - parsed : parsed
      end
    end
  end
end
