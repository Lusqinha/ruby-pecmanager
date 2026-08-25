# frozen_string_literal: true

module Domain
  # Kept apart from FixedCost on purpose: a subscription has a billing cycle and
  # is the natural candidate when spending has to be cut.
  class Subscription
    MONTHLY = "monthly"
    YEARLY = "yearly"

    attr_reader :id, :user_id, :name, :amount, :due_day, :cycle

    def initialize(name:, amount:, id: nil, user_id: nil, due_day: nil, cycle: MONTHLY)
      @id = id
      @user_id = user_id
      @name = name
      @amount = amount
      @due_day = due_day
      @cycle = cycle
    end

    def yearly? = cycle == YEARLY

    def monthly_amount = yearly? ? Money.new((amount.cents / 12.0).round) : amount
  end
end
