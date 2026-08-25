# frozen_string_literal: true

module Features
  module Help
    class Handler < Shared::Handler
      route "/start", to: :show
      route "/ajuda", to: :show
      route "/help", to: :show

      def initialize(presenter:)
        @presenter = presenter
      end

      def show(_request) = @presenter.call
    end
  end
end
