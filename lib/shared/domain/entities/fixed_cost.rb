# frozen_string_literal: true

module Domain
  class FixedCost
    FIXED = "fixed"
    PERCENT = "pct"

    attr_reader :id, :user_id, :name, :amount, :due_day, :kind

    # kind 'pct': amount guarda centésimos de ponto percentual (600 = 6,00%),
    # aplicados sobre a receita bruta — imposto acompanha a receita sem ninguém
    # recalcular à mão. deduction: sai antes da renda líquida, ao contrário de
    # um custo de vida como aluguel.
    def initialize(name:, amount:, id: nil, user_id: nil, due_day: nil, kind: FIXED, deduction: false)
      @id = id
      @user_id = user_id
      @name = name
      @amount = amount
      @due_day = due_day
      @kind = kind.to_s
      @deduction = deduction ? true : false
    end

    def deduction? = @deduction
    def percent? = kind == PERCENT

    def monthly_amount(salary = nil)
      return amount unless percent?

      Money.new((salary || Money.zero).cents * amount.cents / 10_000)
    end
  end
end
