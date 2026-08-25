# frozen_string_literal: true

require_relative "../test_helper"

class AllocationTest < Minitest::Test
  def goal(name, target, deadline: nil, saved: 0)
    Domain::Goal.new(name: name, target: money(target), saved: money(saved), deadline: deadline)
  end

  def test_a_single_box_takes_everything
    shares = Domain::Allocation.of(money(160_000), [goal("reserva", 1_000_000)])

    assert_equal 160_000, shares.first.amount.cents
    assert shares.first.priority?
  end

  # 90% para o prazo mais curto, 10% rateado — a outra nunca fica zerada.
  def test_the_tightest_deadline_leads_and_the_rest_still_gets_something
    shares = Domain::Allocation.of(money(160_000), [
                                     goal("reserva", 1_100_000, deadline: Date.new(2027, 10, 1)),
                                     goal("notebook", 500_000, deadline: Date.new(2027, 2, 1))
                                   ])

    assert_equal %w[notebook reserva], shares.map(&:name)
    assert_equal [144_000, 16_000], shares.map { |share| share.amount.cents }
    assert_equal money(160_000), shares.reduce(Domain::Money.zero) { |sum, share| sum + share.amount }
  end

  def test_the_shared_tenth_follows_what_each_one_still_needs
    shares = Domain::Allocation.of(money(100_000), [
                                     goal("prioridade", 1_000_000, deadline: Date.new(2027, 1, 1)),
                                     goal("pequena", 10_000),
                                     goal("grande", 90_000)
                                   ])

    assert_equal [90_000, 1_000, 9_000], shares.map { |share| share.amount.cents }
  end

  # Caixinha quase cheia não engole a sobra inteira: o excedente escorre.
  def test_nobody_gets_more_than_what_is_missing
    shares = Domain::Allocation.of(money(100_000), [
                                     goal("quase", 100_000, saved: 95_000, deadline: Date.new(2026, 9, 1)),
                                     goal("longe", 1_000_000, deadline: Date.new(2027, 9, 1))
                                   ])

    assert_equal [5_000, 95_000], shares.map { |share| share.amount.cents }
  end

  def test_a_full_box_is_left_out
    shares = Domain::Allocation.of(money(50_000), [goal("cheia", 10_000, saved: 10_000),
                                                   goal("aberta", 100_000)])

    assert_equal ["aberta"], shares.map(&:name)
  end

  def test_without_leftover_there_is_nothing_to_distribute
    assert_empty Domain::Allocation.of(money(0), [goal("reserva", 100_000)])
  end
end

class RebalanceTest < Minitest::Test
  def slot(name, limit, spent)
    Domain::Rebalance::Slot.new(name: name, limit: money(limit), spent: money(spent))
  end

  def test_takes_from_the_largest_spare_first
    moves = Domain::Rebalance.moves(money(10_000), [slot("Mercado", 50_000, 45_000),
                                                    slot("Compras", 32_000, 0),
                                                    slot("Lazer", 20_000, 5_000)])

    assert_equal ["Compras"], moves.map(&:from)
    assert_equal 10_000, moves.first.amount.cents
  end

  def test_chains_donors_until_the_hole_is_covered
    moves = Domain::Rebalance.moves(money(40_000), [slot("Compras", 32_000, 0),
                                                    slot("Lazer", 20_000, 5_000)])

    assert_equal [%w[Compras], %w[Lazer]].flatten, moves.map(&:from)
    assert_equal [32_000, 8_000], moves.map { |move| move.amount.cents }
  end

  def test_never_borrows_from_the_category_that_is_receiving
    moves = Domain::Rebalance.moves(money(5_000), [slot("Mercado", 50_000, 0), slot("Lazer", 20_000, 0)],
                                    to: "Mercado")

    assert_equal ["Lazer"], moves.map(&:from)
    assert_equal "Mercado", moves.first.to
  end

  def test_a_category_without_a_limit_lends_nothing
    assert_empty Domain::Rebalance.moves(money(5_000), [slot("Extras", 0, 0)])
  end

  def test_a_category_already_over_its_limit_lends_nothing
    assert_empty Domain::Rebalance.moves(money(5_000), [slot("Mercado", 50_000, 60_000)])
  end
end
