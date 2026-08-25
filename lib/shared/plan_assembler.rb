# frozen_string_literal: true

module Shared
  # Monta o plano financeiro do usuário a partir dos repositórios. Vive no
  # kernel porque relatórios, budgets e exportação pedem o mesmo plano.
  class PlanAssembler
    def initialize(user_repository:, category_repository:, fixed_cost_repository:,
                   subscription_repository:, goal_repository:)
      @user_repository = user_repository
      @category_repository = category_repository
      @fixed_cost_repository = fixed_cost_repository
      @subscription_repository = subscription_repository
      @goal_repository = goal_repository
    end

    def call(user_id:)
      user = @user_repository.find(user_id)
      return nil unless user

      plan = Domain::FinancialPlan.new(
        salary: user.salary,
        categories: @category_repository.for_user(user_id),
        fixed_costs: @fixed_cost_repository.for_user(user_id),
        subscriptions: @subscription_repository.for_user(user_id),
        goals: @goal_repository.for_user(user_id)
      )
      [user, plan]
    end
  end
end
