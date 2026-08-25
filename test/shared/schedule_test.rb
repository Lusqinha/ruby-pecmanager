# frozen_string_literal: true

require_relative "../test_helper"

class ScheduleTest < Minitest::Test
  def schedule = Infrastructure::Schedule.new(weekday: 5, hour: 16)

  def friday(hour, minute = 0) = Time.new(2026, 8, 28, hour, minute, 0)

  def test_fires_on_the_right_weekday_after_the_hour
    assert schedule.due?(friday(16), nil)
    assert schedule.due?(friday(23, 59), nil)
  end

  def test_stays_quiet_before_the_hour
    refute schedule.due?(friday(15, 59), nil)
  end

  def test_stays_quiet_on_other_days
    refute schedule.due?(Time.new(2026, 8, 27, 18, 0, 0), nil)
  end

  # Reiniciar o bot às 16h05 não pode repetir o relatório das 16h.
  def test_does_not_repeat_on_the_same_day
    refute schedule.due?(friday(16, 5), Date.new(2026, 8, 28))
  end

  def test_fires_again_on_the_next_week
    assert schedule.due?(friday(16), Date.new(2026, 8, 21))
  end
end
