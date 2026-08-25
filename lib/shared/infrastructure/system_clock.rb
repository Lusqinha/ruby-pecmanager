# frozen_string_literal: true

require "date"

module Infrastructure
  # Tests inject a frozen clock instead.
  class SystemClock
    def today = Date.today
    def now = Time.now
  end
end
