# frozen_string_literal: true

module Features
  module Savings
    # Cada caixinha guarda o próprio saldo: o que entra numa não aparece na
    # outra, nem no total de outra meta.
    class Deposit
      def initialize(goal_repository:)
        @goal_repository = goal_repository
      end

      def call(user_id:, name:, amount:)
        boxes = @goal_repository.for_user(user_id)
        return Result.new(status: :no_boxes) if boxes.empty?
        return Result.new(status: :missing_amount) unless amount

        box = find(boxes, name)
        return Result.new(status: :unknown_box, names: boxes.map(&:name)) unless box

        updated = @goal_repository.save(with_balance(box, box.saved + amount))
        Result.new(status: :deposited, box: updated, amount: amount)
      end

      private

      # Mesmo casamento por nome que o resto do bot usa, então "viagem" acha
      # "Viagem" e "reserva de emergencia" acha "Reserva de emergência".
      def find(boxes, name)
        normalized = Domain::Categorizer.normalize(name)
        return nil if normalized.empty?

        boxes.find { |box| Domain::Categorizer.normalize(box.name) == normalized } ||
          boxes.find { |box| Domain::Categorizer.normalize(box.name).include?(normalized) }
      end

      # Saldo não fica negativo: retirar mais do que tem esvazia a caixinha.
      def with_balance(box, balance)
        Domain::Goal.new(id: box.id, user_id: box.user_id, name: box.name, target: box.target,
                         saved: [balance, Domain::Money.zero].max, deadline: box.deadline)
      end
    end

    class ViewBoxes
      def initialize(goal_repository:, clock:)
        @goal_repository = goal_repository
        @clock = clock
      end

      def call(user_id:)
        today = @clock.today
        boxes = @goal_repository.for_user(user_id).map do |box|
          BoxLine.new(name: box.name, saved: box.saved, target: box.target,
                      monthly: box.monthly_contribution(today), deadline: box.deadline)
        end

        Result.new(status: :listed, boxes: boxes, today: today)
      end
    end
  end
end
