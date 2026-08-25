# frozen_string_literal: true

module Domain
  # Como dividir a sobra do mês entre as caixinhas. A de prazo mais apertado
  # leva o grosso, mas nenhuma fica zerada: caixinha parada nunca anda, e o
  # usuário perde a noção de que ela existe.
  module Allocation
    PRIORITY_SHARE = 90
    FAR_FUTURE = Date.new(9999, 1, 1)

    Share = Struct.new(:goal, :amount, :priority, keyword_init: true) do
      def priority? = !!priority
      def name = goal.name
    end

    module_function

    def of(leftover, goals)
      pending = goals.reject { |goal| goal.missing.zero? }
      return [] unless leftover.positive? && pending.any?

      cap(split(leftover, by_deadline(pending)))
    end

    # Prazo mais curto primeiro; sem prazo vai para o fim da fila.
    def by_deadline(goals) = goals.sort_by { |goal| goal.deadline || FAR_FUTURE }

    def split(leftover, ordered)
      return [Share.new(goal: ordered.first, amount: leftover, priority: true)] if ordered.size == 1

      head, *rest = ordered
      shared = leftover.percentage(100 - PRIORITY_SHARE)
      [Share.new(goal: head, amount: leftover - shared, priority: true)] + proportional(shared, rest)
    end

    # Entre as não prioritárias, quem está mais longe da meta recebe mais. A
    # última fecha a conta para nenhum centavo sumir no arredondamento.
    def proportional(total, goals)
      missing = goals.reduce(Money.zero) { |sum, goal| sum + goal.missing }
      running = Money.zero

      goals.each_with_index.map do |goal, index|
        amount = if index == goals.size - 1
                   total - running
                 else
                   Money.new(total.cents * goal.missing.cents / missing.cents)
                 end
        running += amount
        Share.new(goal: goal, amount: amount, priority: false)
      end
    end

    # Ninguém recebe mais do que falta: o excedente escorre para a próxima da
    # fila, e o que sobrar depois da última fica livre.
    def cap(shares)
      excess = Money.zero

      shares.map do |share|
        amount = share.amount + excess
        room = share.goal.missing
        excess = [amount - room, Money.zero].max
        Share.new(goal: share.goal, amount: [amount, room].min, priority: share.priority?)
      end
    end
  end
end
