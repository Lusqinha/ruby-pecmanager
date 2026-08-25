# frozen_string_literal: true

module Infrastructure
  # Decide se uma entrega periódica está na hora. Sem relógio próprio e sem
  # efeito colateral: recebe o instante e a data do último envio, devolve
  # true ou false — é o que torna o agendamento testável.
  class Schedule
    attr_reader :weekday, :hour

    # weekday segue Time#wday: 0 domingo, 5 sexta.
    def initialize(weekday:, hour:)
      @weekday = weekday
      @hour = hour
    end

    def due?(now, last_sent_on)
      return false unless now.wday == weekday && now.hour >= hour

      last_sent_on.nil? || last_sent_on < now.to_date
    end
  end
end
