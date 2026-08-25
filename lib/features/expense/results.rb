# frozen_string_literal: true

module Features
  module Expense
    Result = Struct.new(:status, :expense, :category, :categories, :spent_in_month, :limit, :moves,
                        keyword_init: true) do
      def recorded? = status == :recorded
      def needs_category? = status == :needs_category
      def unparseable? = status == :unparseable
      def missing? = status == :missing
    end

    UndoResult = Struct.new(:status, :expense, keyword_init: true) do
      def undone? = status == :undone
      def too_old? = status == :too_old
      def missing? = status == :missing
    end
  end
end
