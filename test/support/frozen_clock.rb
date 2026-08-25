# frozen_string_literal: true

# Implements Ports::Clock with a fixed instant.
class FrozenClock
  attr_accessor :today, :now

  def initialize(today:, now:)
    @today = today
    @now = now
  end
end
