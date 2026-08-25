# frozen_string_literal: true

module Features
  module Installments
    Result = Struct.new(:status, :plan, :plans, :month, :category, :cancelled_count, :in_budget,
                        keyword_init: true)
  end
end
