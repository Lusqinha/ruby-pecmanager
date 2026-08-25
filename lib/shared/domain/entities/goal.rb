# frozen_string_literal: true

module Domain
  class Goal
    attr_reader :id, :user_id, :name, :target, :saved, :deadline

    def initialize(name:, target:, id: nil, user_id: nil, saved: Money.zero, deadline: nil)
      @id = id
      @user_id = user_id
      @name = name
      @target = target
      @saved = saved
      @deadline = deadline
    end

    def missing = [target - saved, Money.zero].max

    # Without a deadline there is no required contribution: the goal takes
    # whatever is left over at the end of the month.
    def monthly_contribution(today)
      return Money.zero if deadline.nil? || missing.zero?

      missing.divided_over(months_until(today))
    end

    def months_until(today)
      months = (deadline.year * 12 + deadline.month) - (today.year * 12 + today.month)
      [months, 1].max
    end
  end
end
