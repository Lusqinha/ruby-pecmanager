# frozen_string_literal: true

module Features
  module Setup
    # Categories that already carry expenses survive even when the new plan drops
    # them, so old reports keep their names.
    class CompleteSetup
      def initialize(user_repository:, category_repository:, fixed_cost_repository:,
                     subscription_repository:, goal_repository:, expense_repository:, clock:)
        @user_repository = user_repository
        @category_repository = category_repository
        @fixed_cost_repository = fixed_cost_repository
        @subscription_repository = subscription_repository
        @goal_repository = goal_repository
        @expense_repository = expense_repository
        @clock = clock
      end

      def call(user_id:, draft:, name: nil)
        existing = @user_repository.find(user_id)
        user = Domain::User.new(id: user_id, name: name || existing&.name,
                                salary: draft.salary || Domain::Money.zero, setup_done_at: @clock.now)
        @user_repository.save(user)

        @category_repository.replace_all(user_id, draft.categories, keep_ids: keep_ids(user_id))
        @fixed_cost_repository.replace_all(user_id, draft.all_fixed_costs)
        @subscription_repository.replace_all(user_id, draft.subscriptions)
        @goal_repository.replace_all(user_id, draft.goals)

        user
      end

      private

      def keep_ids(user_id) = @expense_repository.category_ids_with_expenses(user_id)
    end
  end
end
