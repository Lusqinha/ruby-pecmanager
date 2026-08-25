# frozen_string_literal: true

require_relative "../test_helper"

class ExpenseTest < Minitest::Test
  def expense(created_at:)
    Domain::Expense.new(user_id: 1, amount: money(3_500), spent_on: TODAY,
                        description: "mercado da esquina", created_at: created_at)
  end

  def test_undoable_inside_the_window
    assert expense(created_at: NOW - 120).undoable_at?(NOW)
  end

  def test_not_undoable_after_the_window
    refute expense(created_at: NOW - 600).undoable_at?(NOW)
  end

  def test_first_word_feeds_the_keyword_learning
    assert_equal "mercado", expense(created_at: NOW).first_word
  end

  def test_in_category_returns_a_new_entity
    original = expense(created_at: NOW)
    moved = original.in_category(9)

    assert_equal 9, moved.category_id
    assert_nil original.category_id
  end
end
