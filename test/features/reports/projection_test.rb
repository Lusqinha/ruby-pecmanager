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

  def test_the_horizon_stretches_to_the_longest_goal_deadline
    @factory.seed_user
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "reserva", target: money(1_000_000),
                                                    deadline: Date.new(2027, 2, 1))])

    report = @factory.view_projection.call(user_id: 3)

    assert_equal Date.new(2027, 2, 1), report.lines.last.month
    assert_equal 166_667, report.goals.first.monthly.cents # 1.000.000 em 6 meses
  end

  # Duas caixinhas dividem a mesma sobra: a segunda só fecha depois da primeira.
  def test_goals_queue_up_on_the_same_leftover
    @factory.seed_user
    @factory.goals.replace_all(3, [
                                 Domain::Goal.new(name: "PC", target: money(400_000)),
                                 Domain::Goal.new(name: "Viagem", target: money(400_000))
                               ])

    report = @factory.view_projection.call(user_id: 3)
    first, second = report.goals

    assert first.covered_on < second.covered_on
  end

  def test_a_subscription_inside_a_budget_is_not_subtracted_twice
    @factory.seed_user(categories: [["Assinaturas", []]])
    @factory.subscriptions.replace_all(3, [Domain::Subscription.new(name: "Netflix", amount: money(4_000))])

    report = @factory.view_projection.call(user_id: 3)

    assert report.subscriptions_in_budget?
    # 5.000,00 − 500,00 de budget, e nada a mais pela assinatura.
    assert_equal 450_000, report.lines.first.leftover.cents
  end

  def test_the_projection_message_shows_the_pace_of_each_box_and_a_chart_button
    @factory.seed_user
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "reserva", target: money(1_000_000),
                                                    deadline: Date.new(2027, 8, 1))])

    reply = send_text("/projecao")

    assert_includes reply.text, "guardar *R$ 833,34/mês* até 08/2027"
    assert_includes reply.text, "Mês a mês"
    assert_equal [["Gráfico do acumulado", "chart:accumulated"]], reply.keyboard.flatten(1)
    assert tap_button("chart:accumulated").photo?
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
