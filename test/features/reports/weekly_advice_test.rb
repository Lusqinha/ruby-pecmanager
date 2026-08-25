# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class WeeklyAdviceTest < SliceCase
  # Modelo que responde, que demora demais e que não existe.
  class Advisor
    attr_reader :prompt

    def initialize(answer = nil, &block)
      @answer = answer
      @block = block
    end

    def advise(prompt, timeout: nil)
      @prompt = prompt
      @block ? @block.call : @answer
    end
  end

  def report
    @factory.seed_user
    with_regex_parser
    send_text("300 mercado")
    @factory.router # garante o roteador montado
    Features::Reports::ViewWeekly.new(plan_assembler: plan_assembler, expense_repository: @factory.expenses,
                                      clock: @clock).call(user_id: 3)
  end

  def plan_assembler
    Shared::PlanAssembler.new(user_repository: @factory.users, category_repository: @factory.categories,
                                         fixed_cost_repository: @factory.fixed_costs,
                                         subscription_repository: @factory.subscriptions,
                                         goal_repository: @factory.goals)
  end

  def advice_for(advisor) = Features::Reports::WeeklyAdvice.new(advisor: advisor).call(report)

  def test_sends_the_numbers_and_the_ceiling_as_a_hard_rule
    advisor = Advisor.new("Reduza Transporte em 50 e suba Mercado.")
    result = advice_for(advisor)

    assert_equal "Reduza Transporte em 50 e suba Mercado.", result
    assert_includes advisor.prompt, "Mercado: teto 500.00, gasto 300.00"
    assert_includes advisor.prompt, "não pode aumentar"
  end

  def test_a_long_answer_is_cut_to_what_fits_a_message
    result = advice_for(Advisor.new((["linha"] * 20).join("\n")))

    assert_equal 4, result.lines.size
  end

  def test_a_timeout_becomes_no_advice
    result = advice_for(Advisor.new { raise Net::OpenTimeout, "execution expired" })

    assert_nil result
  end

  def test_an_empty_answer_becomes_no_advice
    assert_nil advice_for(Advisor.new("   "))
  end

  def test_the_weekly_report_survives_without_the_model
    @factory.seed_user
    with_regex_parser
    send_text("300 mercado")
    @factory.parser = Object.new # não sabe aconselhar

    reply = send_text("/semana")

    assert_includes reply.text, "R$ 300,00"
    refute_includes reply.text, "Parecer"
  end
end
