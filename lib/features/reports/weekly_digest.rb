# frozen_string_literal: true

module Features
  module Reports
    # Entrega automática do fechamento da semana. Não conhece Telegram nem
    # thread: recebe o instante, decide se é hora e devolve as mensagens a
    # enviar, marcando o que entregou.
    class WeeklyDigest
      KIND = :weekly

      def initialize(weekly:, presenter:, delivery_repository:, schedule:)
        @weekly = weekly
        @presenter = presenter
        @delivery_repository = delivery_repository
        @schedule = schedule
      end

      # Devolve [[user_id, ViewMessage], ...] — vazio quando não é hora.
      def call(user_ids:, now: Time.now)
        user_ids.filter_map do |user_id|
          next unless due?(user_id, now)

          report = @weekly.call(user_id: user_id)
          next unless report

          @delivery_repository.record(user_id, KIND, now.to_date)
          [user_id, @presenter.weekly(report)]
        end
      end

      private

      def due?(user_id, now)
        @schedule.due?(now, @delivery_repository.last_sent_on(user_id, KIND))
      end
    end
  end
end
