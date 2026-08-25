# frozen_string_literal: true

module Features
  module Account
    RollbackResult = Struct.new(:status, :minutes, :since, :expenses, :plans, keyword_init: true) do
      def empty? = expenses.to_a.empty? && plans.to_a.empty?
      def total = expenses.to_a.size + plans.to_a.size
    end

    WipeResult = Struct.new(:status, keyword_init: true)
  end
end
