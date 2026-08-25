# frozen_string_literal: true

module Features
  module Expense
    class Handler < Shared::Handler
      route "/desfazer", to: :undo_last
      # "cancela", "deixa quieto": desistir sem saber o comando.
      route Interface::CancelWords, to: :undo_last
      callback(/\Acat:(\d+):(\d+)\z/, to: :assign)
      callback(/\Achg:(\d+)\z/, to: :change)
      callback(/\Aundo:(\d+)\z/, to: :undo)
      # Anything that matched no command is an expense in free text.
      fallback :record

      def initialize(record_expense:, assign_category:, prepare_category_change:, undo_expense:, presenter:)
        @record_expense = record_expense
        @assign_category = assign_category
        @prepare_category_change = prepare_category_change
        @undo_expense = undo_expense
        @presenter = presenter
      end

      def record(request)
        @presenter.call(@record_expense.call(user_id: request.user_id, text: request.text))
      end

      def assign(request, expense_id, category_id)
        @presenter.call(@assign_category.call(user_id: request.user_id, expense_id: expense_id.to_i,
                                              category_id: category_id.to_i))
      end

      def change(request, expense_id)
        @presenter.call(@prepare_category_change.call(user_id: request.user_id, expense_id: expense_id.to_i))
      end

      def undo(request, expense_id)
        @presenter.undo(@undo_expense.call(user_id: request.user_id, expense_id: expense_id.to_i))
      end

      def undo_last(request)
        @presenter.undo(@undo_expense.call(user_id: request.user_id))
      end
    end
  end
end
