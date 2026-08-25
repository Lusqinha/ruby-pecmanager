# frozen_string_literal: true

module Domain
  # Aggregate: everything a user's month is made of.
  class FinancialPlan
    # A categoria que recebe as assinaturas cadastradas, quando existe.
    SUBSCRIPTIONS_CATEGORY = "assinaturas"

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

    def subscriptions_total = sum(subscriptions, &:monthly_amount)

    # Com uma categoria "Assinaturas" no plano, as assinaturas cadastradas são o
    # gasto dela: descontá-las também da renda tiraria o mesmo dinheiro duas
    # vezes.
    def subscriptions_category
      categories.find { |category| Categorizer.normalize(category.name) == SUBSCRIPTIONS_CATEGORY }
    end

    def subscriptions_in_budget? = !subscriptions_category.nil?

    # Gasto do mês de uma categoria: o que foi lançado, mais as assinaturas que
    # vivem dentro do teto dela.
    def spent_for(category, totals)
      spent = totals[category.id] || Money.zero
      category.id == subscriptions_category&.id ? spent + subscriptions_total : spent
    end

    def committed = sum(categories) { |category| category.budget_for(net_income) }

    # O que sobra depois de honrar tetos, fixos e parcelas: é daqui que saem as
    # caixinhas, e é o mesmo número no mês corrente e na projeção.
    def leftover(installments = Money.zero)
      net_income - committed - living_costs - installments -
        (subscriptions_in_budget? ? Money.zero : subscriptions_total)
    end

    def summary(today)
      BudgetSummary.new(
        salary: net_income,
        fixed_costs: living_costs,
        subscriptions: subscriptions_total,
        subscriptions_in_budget: subscriptions_in_budget?,
        goals: sum(goals) { |goal| goal.monthly_contribution(today) },
        committed: committed
      )
    end

    private

    def sum(items)
      items.reduce(Money.zero) { |total, item| total + yield(item) }
    end
  end
end
