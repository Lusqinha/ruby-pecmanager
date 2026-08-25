# frozen_string_literal: true

module Domain
  # Remanejo de teto dentro do mês: quem não usou o budget empresta para quem
  # está no limite. A soma dos tetos nunca muda — o mês não pode estourar por
  # causa de um remanejo.
  module Rebalance
    # to é o nome de quem recebe, ou nil quando o dinheiro vai para as
    # caixinhas em vez de outra categoria.
    Move = Struct.new(:from, :amount, :spent, :limit, :to, keyword_init: true)

    Slot = Struct.new(:name, :limit, :spent, keyword_init: true) do
      # Só empresta o que ainda não foi gasto, e teto sem limite não empresta:
      # não há cota para tirar de onde nunca houve teto.
      def spare = limit.zero? ? Money.zero : [limit - spent, Money.zero].max
    end

    module_function

    def moves(needed, slots, to: nil)
      return [] unless needed.positive?

      donors(slots, to).each_with_object([]) do |slot, moves|
        taken = moves.reduce(Money.zero) { |sum, move| sum + move.amount }
        break moves if taken >= needed

        amount = [slot.spare, needed - taken].min
        moves << Move.new(from: slot.name, amount: amount, spent: slot.spent, limit: slot.limit, to: to)
      end
    end

    # Maior folga primeiro: tirar de quem menos usou o mês é o corte que menos
    # dói.
    def donors(slots, receiver)
      slots.reject { |slot| slot.name == receiver }
           .select { |slot| slot.spare.positive? }
           .sort_by { |slot| -slot.spare.cents }
    end
  end
end
