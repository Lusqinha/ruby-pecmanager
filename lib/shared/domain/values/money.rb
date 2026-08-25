# frozen_string_literal: true

module Domain
  # Integer cents only: no float ever touches money. Parsing and formatting are
  # delivery concerns and live outside the domain.
  class Money
    include Comparable

    attr_reader :cents

    def initialize(cents)
      @cents = Integer(cents)
      freeze
    end

    def self.zero = new(0)

    def +(other) = self.class.new(cents + other.cents)
    def -(other) = self.class.new(cents - other.cents)
    def *(factor) = self.class.new((cents * factor).round)

    def percentage(pct) = self.class.new(cents * pct / 100)

    def divided_over(parts) = self.class.new((cents.to_f / [parts, 1].max).ceil)

    def <=>(other) = cents <=> other.cents
    def positive? = cents.positive?
    def negative? = cents.negative?
    def zero? = cents.zero?
    def to_i = cents
    def eql?(other) = other.is_a?(Money) && other.cents == cents
    def hash = cents.hash
    def inspect = "#<Domain::Money #{cents}>"
  end
end
