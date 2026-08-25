# frozen_string_literal: true

module Features
  module Reports
    class Handler < Shared::Handler
      route "/hoje", to: :daily
      route "/semana", to: :weekly
      route "/grafico", to: :menu
      route "/gráfico", to: :menu
      callback("chart:categories", to: :chart)
      callback("chart:months", to: :history)
      callback("chart:accumulated", to: :accumulated)
      route(%r{\A/m[eê]s\s+(.+)\z}i, to: :monthly_at)
      route "/mes", to: :monthly
      route "/mês", to: :monthly
      callback(/\Amonth:(\d{4})-(\d{2})\z/, to: :monthly_on)
      route "/projecao", to: :projection
      route "/projeção", to: :projection
      route(%r{\A/categoria(?:\s+(.+))?\z}i, to: :category)

      def initialize(daily:, monthly:, category:, projection:, history:, weekly:, advice:, presenter:, clock:)
        @clock = clock
        @advice = advice
        @weekly = weekly
        @history = history
        @daily = daily
        @monthly = monthly
        @category = category
        @projection = projection
        @presenter = presenter
      end

      def daily(request) = @presenter.daily(@daily.call(user_id: request.user_id))
      def menu(_request) = @presenter.chart_menu
      def weekly(request)
        report = @weekly.call(user_id: request.user_id)
        @presenter.weekly(report, report && @advice.call(report))
      end
      def chart(request) = @presenter.chart(@monthly.call(user_id: request.user_id))
      def history(request) = @presenter.history(@history.call(user_id: request.user_id))
      def monthly(request) = @presenter.monthly(@monthly.call(user_id: request.user_id))

      # "/mes out/26": o mês escrito como se fala, e a navegação pelos botões
      # manda a data já resolvida.
      def monthly_at(request, hint)
        month = Interface::MonthParser.parse(hint, today: @clock.today)
        return @presenter.unknown_month unless month

        @presenter.monthly(@monthly.call(user_id: request.user_id, month: month))
      end

      def monthly_on(request, year, month)
        @presenter.monthly(@monthly.call(user_id: request.user_id, month: Date.new(year.to_i, month.to_i, 1)))
      end
      def projection(request) = @presenter.projection(@projection.call(user_id: request.user_id))
      def accumulated(request) = @presenter.accumulated_chart(@projection.call(user_id: request.user_id))

      def category(request, hint = nil)
        @presenter.category(@category.call(user_id: request.user_id, hint: hint.to_s))
      end
    end
  end
end
