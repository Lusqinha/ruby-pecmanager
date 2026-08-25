# frozen_string_literal: true

module Interface
  # O usuário escreve o mês como fala: "out/26", "10/2026", "outubro", "10".
  module MonthParser
    NAMES = %w[janeiro fevereiro marco abril maio junho julho agosto setembro outubro novembro dezembro].freeze
    # A normalização já trocou "/", "-" e "." por espaço.
    NUMERIC = /\A(\d{1,2})(?:\s+(\d{2}|\d{4}))?\z/
    NAMED = /\A([a-z]{3,})(?:\s+(\d{2}|\d{4}))?\z/

    module_function

    def parse(text, today:)
      normalized = Domain::Categorizer.normalize(text)
      month, year = numeric(normalized) || named(normalized)
      return nil unless month&.between?(1, 12)

      Date.new(year_for(year, month, today), month, 1)
    end

    def numeric(text)
      found = NUMERIC.match(text)
      found && [found[1].to_i, found[2]]
    end

    def named(text)
      found = NAMED.match(text)
      return nil unless found

      index = NAMES.index { |name| name.start_with?(found[1]) }
      index && [index + 1, found[2]]
    end

    # Ano de dois dígitos é deste século. Sem ano, "outubro" é o outubro que
    # ainda vem — pedir um mês já vencido é o caso raro.
    def year_for(year, month, today)
      return today.year + (month < today.month ? 1 : 0) unless year

      year.size == 2 ? 2000 + year.to_i : year.to_i
    end
  end
end
