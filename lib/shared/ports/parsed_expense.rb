# frozen_string_literal: true

module Ports
  # What every ExpenseParser returns, whatever provider is behind it.
  ParsedExpense = Struct.new(:amount, :description, :category_hint, :spent_on, :source, keyword_init: true)
end
