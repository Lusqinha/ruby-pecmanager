# frozen_string_literal: true

module Domain
  # What a financial plan adds up to in a month.
  class BudgetSummary
    attr_reader :salary, :fixed_costs, :subscriptions, :goals, :committed

    def initialize(salary:, fixed_costs:, subscriptions:, goals:, committed:)
      @salary = salary
      @fixed_costs = fixed_costs
      @subscriptions = subscriptions
      @goals = goals
      @committed = committed
      freeze
    end

    # What is left for the categories after the untouchable commitments.
    def available = salary - fixed_costs - subscriptions - goals

    def over = [committed - available, Money.zero].max
    def over? = over.positive?
  end
end
