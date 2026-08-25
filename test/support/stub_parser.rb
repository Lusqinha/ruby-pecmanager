# frozen_string_literal: true

# Stands in for Ports::ExpenseParser. nil means "LLM unavailable".
class StubParser
  attr_reader :seen_categories

  def initialize(result = nil) = @result = result

  def parse(_text, today: nil, categories: [])
    @seen_categories = categories
    @result
  end
end
