# frozen_string_literal: true

require "minitest/autorun"
require "date"
require_relative "../lib/config/boot"
require_relative "support/frozen_clock"
require_relative "support/in_memory_repositories"

TODAY = Date.new(2026, 8, 24) # a Monday, so weekday parsing is deterministic
NOW = Time.new(2026, 8, 24, 12, 0, 0)

def money(cents) = Domain::Money.new(cents)
