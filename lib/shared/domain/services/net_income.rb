# frozen_string_literal: true

module Domain
  # Renda que de fato circula: bruto menos o que sai antes (imposto, INSS,
  # contabilidade). Vive aqui porque tanto o plano quanto os lançamentos precisam
  # dela, e nenhum dos dois pode ficar com uma cópia da regra.
  module NetIncome
    module_function

    def of(salary, fixed_costs)
      fixed_costs.select(&:deduction?)
                 .reduce(salary) { |total, item| total - item.monthly_amount(salary) }
    end
  end
end
