# frozen_string_literal: true

module Interface
  module Brl
    BAR_WIDTH = 10

    module_function

    def format(money)
      cents = money.respond_to?(:cents) ? money.cents : money.to_i
      sign = cents.negative? ? "-" : ""
      units, decimals = cents.abs.divmod(100)
      "#{sign}R$ #{group(units)},#{decimals.to_s.rjust(2, '0')}"
    end

    def group(units)
      units.to_s.reverse.scan(/\d{1,3}/).join(".").reverse
    end

    def bar(spent, limit)
      pct = (spent.cents * 100.0 / limit.cents).round
      filled = [[(pct * BAR_WIDTH / 100.0).round, 0].max, BAR_WIDTH].min
      ["#{'█' * filled}#{'░' * (BAR_WIDTH - filled)}", pct]
    end
  end
end
