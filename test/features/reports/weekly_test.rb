# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class WeeklyTest < SliceCase
  # TODAY dos testes é 2026-08-24, uma segunda: a semana começa no próprio dia.
  def test_shows_the_week_spending_and_the_daily_pace_left
    @factory.seed_user
    with_regex_parser
    send_text("300 mercado")

    reply = send_text("/semana")

    assert_includes reply.text, "R$ 300,00"
    # Teto de Mercado é 500; restam 200 e 8 dias de agosto, hoje incluído
    assert_includes reply.text, "R$ 200,00"
    assert_includes reply.text, "8 dias"
    assert_includes reply.text, "R$ 25,00/dia"
  end

  def test_warns_when_the_current_pace_breaks_the_budget
    @factory.seed_user
    with_regex_parser
    send_text("480 mercado")

    reply = send_text("/semana")

    assert_includes reply.text, "Mercado"
    assert_includes reply.text, "R$ 20,00"
  end

  def test_a_week_without_spending_still_reports_the_budget
    @factory.seed_user

    reply = send_text("/semana")

    assert_includes reply.text, "Nenhum gasto"
  end
end
