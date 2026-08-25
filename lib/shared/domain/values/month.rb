# frozen_string_literal: true

require "date"

module Domain
  # The window every report and every budget check agrees on.
  module Month
    module_function

    def first_of(date) = Date.new(date.year, date.month, 1)

    def advance(month, count) = first_of(month) >> count

    # Quantos meses de distância, com sinal.
    def distance(from, to) = ((to.year - from.year) * 12) + (to.month - from.month)

    def range(date)
      first = first_of(date)
      first..(first.next_month - 1)
    end
  end
end
