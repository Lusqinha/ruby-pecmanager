# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class InstallmentFlowTest < SliceCase
  def test_records_a_plan_with_the_category_resolved_deterministically
    @factory.seed_user

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
    assert_equal [["Encerrar uber mensal", "plan:cancel:1"]], reply.keyboard.flatten(1)
  end

  def test_cancelling_keeps_this_month_and_drops_the_rest
    @factory.seed_user
    send_text("1200 em 12x uber mensal")

    reply = tap_button("plan:cancel:1")
    plan = @factory.installment_plans.find(3, 1)

    assert plan.cancelled?
    assert_includes reply.text, "Encerrado"
    assert_nil plan.due_in(TODAY.next_month)
    assert_equal 100_00, plan.due_in(TODAY).cents
  end

  def test_an_expense_with_no_count_still_goes_to_the_expense_slice
    @factory.seed_user
    send_text("35 mercado")

    assert_equal 1, @factory.expenses.rows.size
    assert_empty @factory.installment_plans.for_user(3)
  end
end
