# frozen_string_literal: true

module Features
  module Budgets
    Result = Struct.new(:status, :month, :category_name, :previous, :lines, :summary, :net_income, :names,
                        keyword_init: true)
    # limit é o BudgetLimit, para a listagem dizer "20%" em vez de só o valor
    # que ele dá neste mês.
    BudgetLine = Struct.new(:category_name, :limit, :amount, keyword_init: true)
  end
end
