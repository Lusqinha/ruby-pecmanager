# frozen_string_literal: true

module Domain
  class User
    attr_reader :id, :name, :salary, :setup_done_at

    def initialize(id:, salary: Money.zero, name: nil, setup_done_at: nil)
      @id = id
      @name = name
      @salary = salary
      @setup_done_at = setup_done_at
    end

    def setup_done? = !setup_done_at.nil?
  end
end
