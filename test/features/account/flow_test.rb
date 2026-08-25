# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class AccountFlowTest < SliceCase
  def seed_and_book
    @factory.seed_user
    send_text("35 mercado")
    send_text("1200 em 12x uber mensal")
  end

  def test_shows_what_would_be_undone_without_touching_anything
    seed_and_book

    reply = send_text("/reverter 30")

    assert_includes reply.text, "35,00"
    assert_includes reply.text, "uber mensal"
    assert_includes reply.text, "30 min"
    assert_equal 1, @factory.expenses.rows.size
    assert_equal 1, @factory.installment_plans.for_user(3).size
    assert_includes reply.keyboard.flatten(1).map(&:last), "wipe:no"
  end

  def test_confirming_removes_what_was_listed
    seed_and_book
    reply = send_text("/reverter 30")
    data = reply.keyboard.flatten(1).map(&:last).find { |item| item.start_with?("rollback:") }

    tap_button(data)

    assert_empty @factory.expenses.rows
    assert_empty @factory.installment_plans.for_user(3)
  end

  def test_what_happened_before_the_window_survives
    @factory.seed_user
    send_text("35 mercado")
    @clock.now = NOW + (40 * 60)
    send_text("50 uber")

    reply = send_text("/reverter 30")
    tap_button(reply.keyboard.flatten(1).map(&:last).find { |item| item.start_with?("rollback:") })

    remaining = @factory.expenses.rows.values

    assert_equal 1, remaining.size
    assert_equal 3_500, remaining.first.amount.cents
  end

  def test_an_empty_window_says_so
    @factory.seed_user

    assert_includes send_text("/reverter 5").text, "Nenhum lançamento"
  end

  def test_refuses_a_window_without_a_number
    @factory.seed_user

    assert_includes send_text("/reverter").text, "quantos minutos"
  end

  def test_wiping_asks_before_deleting
    seed_and_book

    reply = send_text("/apagar_tudo")

    assert_includes reply.text, "apaga"
    refute_nil @factory.users.find(3)
    assert_equal 1, @factory.expenses.rows.size
  end

  def test_wiping_confirmed_leaves_nothing_behind
    seed_and_book

    reply = tap_button("wipe:yes")

    assert_nil @factory.users.find(3)
    assert_nil @factory.drafts.find(3)
    assert_includes reply.text, "apagado"
  end

  def test_wiping_cancelled_keeps_everything
    seed_and_book

    tap_button("wipe:no")

    refute_nil @factory.users.find(3)
    assert_equal 1, @factory.expenses.rows.size
  end
end
