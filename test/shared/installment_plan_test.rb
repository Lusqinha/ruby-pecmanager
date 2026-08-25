# frozen_string_literal: true

require_relative "../test_helper"

class InstallmentPlanTest < Minitest::Test
  def money(cents) = Domain::Money.new(cents)

  def plan(total: 120_000, count: 12, first: Date.new(2026, 8, 1), cancelled_on: nil)
    Domain::InstallmentPlan.new(user_id: 3, description: "Notebook", total: money(total),
                                count: count, first_month: first, cancelled_on: cancelled_on)
  end

  def test_splits_evenly_when_it_divides
    assert_equal 10_000, plan.amount_for(1).cents
    assert_equal 10_000, plan.amount_for(12).cents
  end

  def test_the_remainder_lands_on_the_last_installment
    item = plan(total: 10_000, count: 3)

    assert_equal 3_333, item.amount_for(1).cents
    assert_equal 3_333, item.amount_for(2).cents
    assert_equal 3_334, item.amount_for(3).cents
    assert_equal 10_000, (1..3).sum { |n| item.amount_for(n).cents }
  end

  def test_knows_which_installment_falls_in_a_month
    assert_equal 1, plan.number_in(Date.new(2026, 8, 20))
    assert_equal 6, plan.number_in(Date.new(2027, 1, 1))
    assert_nil plan.number_in(Date.new(2026, 7, 1))
    assert_nil plan.number_in(Date.new(2027, 8, 1))
  end

  def test_last_month_is_the_first_plus_count_minus_one
    assert_equal Date.new(2027, 7, 1), plan.last_month
  end

  def test_cancelling_keeps_the_current_month_and_drops_the_rest
    item = plan.cancel(on: Date.new(2026, 10, 15))

    assert_equal 10_000, item.due_in(Date.new(2026, 10, 1)).cents
    assert_nil item.due_in(Date.new(2026, 11, 1))
    assert item.cancelled?
  end

  def test_labels_the_installment_for_display
    assert_equal "6/12", plan.label_in(Date.new(2027, 1, 1))
  end
end
