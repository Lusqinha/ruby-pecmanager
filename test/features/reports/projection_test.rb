# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class ProjectionTest < SliceCase
  def test_projects_until_the_last_installment_and_accumulates
    @factory.seed_user
    send_text("1200 em 12x uber mensal")

    reply = send_text("/projecao")
    report = @factory.view_projection.call(user_id: 3)

    assert_equal 12, report.lines.size
    assert_equal Domain::Month.first_of(TODAY), report.lines.first.month
    assert_equal 10_000, report.lines.first.installments.cents
    assert_equal report.lines[0].leftover.cents + report.lines[1].leftover.cents,
                 report.lines[1].accumulated.cents
    assert_includes reply.text, "Projeção"
  end

  def test_without_plans_it_still_shows_three_months
    @factory.seed_user

    report = @factory.view_projection.call(user_id: 3)

    assert_equal 3, report.lines.size
    assert(report.lines.all? { |line| line.installments.zero? })
  end

  def test_marks_the_month_a_goal_is_covered
    @factory.seed_user
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "PC", target: Domain::Money.new(400_000))])

    report = @factory.view_projection.call(user_id: 3)
    goal = report.goals.find { |item| item.name == "PC" }

    refute_nil goal.covered_on
    assert goal.covered_on >= Domain::Month.first_of(TODAY)
  end

  def test_the_net_income_is_the_salary_minus_deductions
    @factory.seed_user
    @factory.fixed_costs.replace_all(3, [
                                       Domain::FixedCost.new(name: "Imposto", amount: Domain::Money.new(600),
                                                             kind: "pct", deduction: true),
                                       Domain::FixedCost.new(name: "Aluguel", amount: Domain::Money.new(90_000))
                                     ])

    report = @factory.view_projection.call(user_id: 3)

    # 5.000,00 − 6% = 4.700,00
    assert_equal 470_000, report.net_income.cents
  end
end
