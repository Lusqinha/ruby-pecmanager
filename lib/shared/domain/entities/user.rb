# frozen_string_literal: true

module Domain
  class User
    attr_reader :id, :name, :salary, :setup_done_at

    def initialize(id:, salary: Money.zero, name: nil, setup_done_at: nil, installments_in_budget: false)
      @id = id
      @name = name
      @salary = salary
      @setup_done_at = setup_done_at
      @installments_in_budget = installments_in_budget ? true : false
    end

    def setup_done? = !setup_done_at.nil?

    # Parcela dentro do teto da categoria ou em bloco à parte. Desligado,
    # nem categoria a parcela precisa ter.
    def installments_in_budget? = @installments_in_budget

    def with_installments_in_budget(value)
      self.class.new(id: id, name: name, salary: salary, setup_done_at: setup_done_at,
                     installments_in_budget: value)
    end
  end
end
