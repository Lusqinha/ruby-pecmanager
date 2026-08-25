# frozen_string_literal: true

module Domain
  # What a financial plan adds up to in a month.
  class BudgetSummary
    attr_reader :salary, :fixed_costs, :subscriptions, :goals, :committed

    def initialize(salary:, fixed_costs:, subscriptions:, goals:, committed:, subscriptions_in_budget: false)
      @salary = salary
      @fixed_costs = fixed_costs
      @subscriptions = subscriptions
      @subscriptions_in_budget = subscriptions_in_budget
      @goals = goals
      @committed = committed
      freeze
    end

    def subscriptions_in_budget? = @subscriptions_in_budget

    # What is left for the categories after the untouchable commitments.
    # Assinatura que já ocupa o teto de uma categoria sai pelo committed, não
    # aqui.
    def available
      salary - fixed_costs - goals - (subscriptions_in_budget? ? Money.zero : subscriptions)
    end

    # O que ainda dá pra distribuir entre as categorias.
    def free = available - committed

    def over = [committed - available, Money.zero].max
    def over? = over.positive?
  end
end
