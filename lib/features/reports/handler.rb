# frozen_string_literal: true

module Features
  module Reports
    class Handler < Shared::Handler
      route "/hoje", to: :daily
      route "/grafico", to: :chart
      route "/gráfico", to: :chart
      route "/grafico_meses", to: :history
      route "/mes", to: :monthly
      route "/mês", to: :monthly
      route "/projecao", to: :projection
      route "/projeção", to: :projection
      route(%r{\A/categoria(?:\s+(.+))?\z}i, to: :category)

      def initialize(daily:, monthly:, category:, projection:, history:, presenter:)
        @history = history
        @daily = daily
        @monthly = monthly
        @category = category
        @projection = projection
        @presenter = presenter
      end

      def daily(request) = @presenter.daily(@daily.call(user_id: request.user_id))
      def chart(request) = @presenter.chart(@monthly.call(user_id: request.user_id))
      def history(request) = @presenter.history(@history.call(user_id: request.user_id))
      def monthly(request) = @presenter.monthly(@monthly.call(user_id: request.user_id))
      def projection(request) = @presenter.projection(@projection.call(user_id: request.user_id))

      def category(request, hint = nil)
        @presenter.category(@category.call(user_id: request.user_id, hint: hint.to_s))
      end
    end
  end
end
