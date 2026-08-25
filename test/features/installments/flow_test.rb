# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class InstallmentFlowTest < SliceCase
  def test_records_a_plan_with_the_category_resolved_deterministically
    @factory.seed_user
    tap_button("plan:budget:on")

    reply = send_text("1200 em 12x uber mensal")
    plan = @factory.installment_plans.for_user(3).first

    assert_equal 120_000, plan.total.cents
    assert_equal 12, plan.count
    assert_equal "Transporte", @factory.categories.find(3, plan.category_id).name
    assert_includes reply.text, "12x"
    assert_empty @factory.expenses.rows
  end

  def test_lists_the_active_plans_with_the_month_total
    @factory.seed_user
    send_text("1200 em 12x uber mensal")

    reply = send_text("/parcelas")

    assert_includes reply.text, "1/12"
    assert_includes reply.text, "R$ 100,00"
    assert_equal [["Encerrar uber mensal", "plan:cancel:1"], ["Contar no budget: não", "plan:budget:on"]],
                 reply.keyboard.flatten(1)
  end

  def test_cancelling_keeps_this_month_and_drops_the_rest
    @factory.seed_user
    send_text("1200 em 12x uber mensal")

    reply = tap_button("plan:cancel:1")
    plan = @factory.installment_plans.find(3, 1)

    assert plan.cancelled?
    assert_includes reply.text, "Parcelamento encerrado"
    assert_nil plan.due_in(TODAY.next_month)
    assert_equal 100_00, plan.due_in(TODAY).cents
  end

  def test_an_expense_with_no_count_still_goes_to_the_expense_slice
    @factory.seed_user
    send_text("35 mercado")

    assert_equal 1, @factory.expenses.rows.size
    assert_empty @factory.installment_plans.for_user(3)
  end
  # Plano que ainda não começou perde todas as parcelas, não zero.
  def test_cancelling_a_plan_that_has_not_started_reports_every_instalment
    @factory.seed_user
    send_text("1200 em 12x uber mensal a partir de #{(TODAY >> 2).strftime('%m/%Y')}")

    reply = tap_button("plan:cancel:1")

    assert_includes reply.text, "12 parcela"
    assert_nil @factory.installment_plans.find(3, 1).due_in(TODAY >> 2)
  end
  def test_the_toggle_shows_the_current_choice_and_flips_it
    @factory.seed_user
    send_text("1200 em 12x uber mensal")

    assert_includes send_text("/parcelas").keyboard.flatten(1).map(&:first), "Contar no budget: não"

    reply = tap_button("plan:budget:on")

    assert @factory.users.find(3).installments_in_budget?
    assert_includes reply.text, "budget"
    assert_includes send_text("/parcelas").keyboard.flatten(1).map(&:first), "Contar no budget: sim"
  end

  # Fora do budget a parcela não precisa de categoria, e o modelo não é
  # consultado por causa dela.
  def test_a_plan_is_not_categorized_when_it_stays_out_of_the_budget
    @factory.seed_user
    counting = CountingParser.new
    @factory.parser = counting

    send_text("900 em 3x cadeira gamer")

    assert_nil @factory.installment_plans.for_user(3).first.category_id
    assert_equal 0, counting.calls
  end

  def test_a_plan_is_categorized_when_it_counts_against_the_budget
    @factory.seed_user
    tap_button("plan:budget:on")

    send_text("1200 em 12x uber mensal")
    plan = @factory.installment_plans.for_user(3).first

    assert_equal "Transporte", @factory.categories.find(3, plan.category_id).name
  end

  class CountingParser
    attr_reader :calls

    def initialize = @calls = 0

    def parse(_text, today: nil, categories: [])
      @calls += 1
      nil
    end
  end
end
