# frozen_string_literal: true

module Domain
  # Aggregate: everything a user's month is made of.
  class FinancialPlan
    attr_reader :salary, :categories, :fixed_costs, :subscriptions, :goals

    def initialize(salary:, categories: [], fixed_costs: [], subscriptions: [], goals: [])
      @salary = salary
      @categories = categories
      @fixed_costs = fixed_costs
      @subscriptions = subscriptions
      @goals = goals
    end

    def deductions = sum(fixed_costs.select(&:deduction?)) { |item| item.monthly_amount(salary) }
    def living_costs = sum(fixed_costs.reject(&:deduction?)) { |item| item.monthly_amount(salary) }
    def net_income = NetIncome.of(salary, fixed_costs)

    def summary(today)
      BudgetSummary.new(
        salary: net_income,
        fixed_costs: living_costs,
        subscriptions: sum(subscriptions, &:monthly_amount),
        goals: sum(goals) { |goal| goal.monthly_contribution(today) },
        committed: sum(categories) { |category| category.budget_for(net_income) }
      )
    end

    private

    def sum(items)
      items.reduce(Money.zero) { |total, item| total + yield(item) }
    end
  end
end
