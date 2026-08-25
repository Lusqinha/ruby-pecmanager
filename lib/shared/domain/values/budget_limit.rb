# frozen_string_literal: true

module Domain
  # How much a category may consume: a share of the salary, a fixed amount, or
  # nothing at all.
  class BudgetLimit
    PERCENT = :pct
    FIXED = :fixed

    attr_reader :kind, :value

    def initialize(kind:, value: 0)
      @kind = kind&.to_sym
      @value = value
      freeze
    end

    def self.none = new(kind: nil)
    def self.percent(pct) = new(kind: PERCENT, value: Integer(pct))
    def self.fixed(money) = new(kind: FIXED, value: money)

    def none? = kind.nil?
    def percent? = kind == PERCENT
    def fixed? = kind == FIXED

    def cents_for(salary)
      case kind
      when PERCENT then salary.percentage(value)
      when FIXED then value
      else Money.zero
      end
    end
  end
end
