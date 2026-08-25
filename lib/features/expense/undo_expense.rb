# frozen_string_literal: true

module Features
  module Expense
    class UndoExpense
      def initialize(expense_repository:, clock:)
        @expense_repository = expense_repository
        @clock = clock
      end

      def call(user_id:, expense_id: nil)
        expense = expense_id ? @expense_repository.find(user_id, expense_id) : @expense_repository.last_for(user_id)
        return UndoResult.new(status: :missing) unless expense
        return UndoResult.new(status: :too_old, expense: expense) unless expense.undoable_at?(@clock.now)

        @expense_repository.delete(user_id, expense.id)
        UndoResult.new(status: :undone, expense: expense)
      end
    end
  end
end
