# frozen_string_literal: true

module Features
  module Expense
    class AssignCategory
      def initialize(user_repository:, category_repository:, expense_repository:)
        @user_repository = user_repository
        @category_repository = category_repository
        @expense_repository = expense_repository
      end

      def call(user_id:, expense_id:, category_id:)
        expense = @expense_repository.find(user_id, expense_id)
        category = @category_repository.find(user_id, category_id)
        return Result.new(status: :missing) unless expense && category

        expense = @expense_repository.save(expense.in_category(category.id))
        # The correction teaches the matcher: next time the word lands by itself,
        # with no LLM round trip.
        category = @category_repository.save(category.with_keyword(expense.first_word))

        Support.recorded(expense, category, @expense_repository, @user_repository.find(user_id))
      end
    end

    class PrepareCategoryChange
      def initialize(category_repository:, expense_repository:)
        @category_repository = category_repository
        @expense_repository = expense_repository
      end

      def call(user_id:, expense_id:)
        expense = @expense_repository.find(user_id, expense_id)
        return Result.new(status: :missing) unless expense

        Result.new(status: :needs_category, expense: expense,
                               categories: @category_repository.for_user(user_id))
      end
    end
  end
end
