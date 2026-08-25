# frozen_string_literal: true

module Features
  module Savings
    Result = Struct.new(:status, :box, :amount, :boxes, :names, :today, keyword_init: true)
    BoxLine = Struct.new(:name, :saved, :target, :monthly, :deadline, keyword_init: true) do
      def missing = [target - saved, Domain::Money.zero].max
      def complete? = missing.zero?
    end
  end
end
