# frozen_string_literal: true

module Features
  module Reports
    class Handler < Shared::Handler
      route "/hoje", to: :daily
      route "/mes", to: :monthly
      route "/mês", to: :monthly
      route "/metas", to: :goals
      route "/projecao", to: :projection
      route "/projeção", to: :projection
      route(%r{\A/categoria(?:\s+(.+))?\z}i, to: :category)

      def initialize(daily:, monthly:, category:, goals:, projection:, presenter:)
        @daily = daily
        @monthly = monthly
        @category = category
        @goals = goals
        @projection = projection
        @presenter = presenter
      end

      def daily(request) = @presenter.daily(@daily.call(user_id: request.user_id))
      def monthly(request) = @presenter.monthly(@monthly.call(user_id: request.user_id))
      def goals(request) = @presenter.goals(@goals.call(user_id: request.user_id))
      def projection(request) = @presenter.projection(@projection.call(user_id: request.user_id))

      def category(request, hint = nil)
        @presenter.category(@category.call(user_id: request.user_id, hint: hint.to_s))
      end
    end
  end
end
