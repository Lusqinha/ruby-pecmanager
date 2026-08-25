# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class WeeklyDigestTest < SliceCase
  FRIDAY_AFTERNOON = Time.new(2026, 8, 28, 16, 0, 0)

  def digest = @factory.weekly_digest

  def test_sends_one_message_per_user_at_the_scheduled_time
    @factory.seed_user
    with_regex_parser
    send_text("300 mercado")

    sent = digest.call(user_ids: [3], now: FRIDAY_AFTERNOON)

    assert_equal 1, sent.size
    assert_equal 3, sent.first.first
    assert_includes sent.first.last.text, "R$ 300,00"
  end

  def test_stays_quiet_outside_the_window
    @factory.seed_user

    assert_empty digest.call(user_ids: [3], now: Time.new(2026, 8, 28, 15, 0, 0))
  end

  # Reiniciar o bot depois do envio não pode repetir a mensagem.
  def test_sends_only_once_per_week
    @factory.seed_user
    digest.call(user_ids: [3], now: FRIDAY_AFTERNOON)

    assert_empty digest.call(user_ids: [3], now: Time.new(2026, 8, 28, 17, 30, 0))
    refute_empty digest.call(user_ids: [3], now: Time.new(2026, 9, 4, 16, 0, 0))
  end

  def test_skips_a_user_without_setup
    assert_empty digest.call(user_ids: [99], now: FRIDAY_AFTERNOON)
  end
end
