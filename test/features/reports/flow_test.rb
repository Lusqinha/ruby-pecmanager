# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class ReportsFlowTest < SliceCase
  def setup
    super
    with_regex_parser
    @factory.seed_user
  end

  def test_monthly_report
    send_text("35 mercado")
    send_text("12,50 uber ontem")

    reply = send_text("/mes")

    assert_includes reply.text, "R$ 47,50"
    assert_includes reply.text, "█"
  end

  def test_daily_report_lists_only_today
    send_text("35 mercado")
    send_text("40 mercado ontem")

    reply = send_text("/hoje")

    assert_includes reply.text, "R$ 35,00"
    refute_includes reply.text, "R$ 40,00"
  end

  def test_category_report
    send_text("35 mercado")

    assert_includes send_text("/categoria mercado").text, "R$ 35,00"
    assert_includes send_text("/categoria nao existe").text, "Não achei"
    assert_includes send_text("/categoria").text, "Não achei"
  end

  def test_goals_report_shows_the_monthly_pace
    run_setup
    reply = send_text("/metas", user_id: 7)

    assert_includes reply.text, "reserva"
    assert_includes reply.text, "/mês"
  end

  def test_help_lists_the_commands
    assert_includes send_text("/ajuda").text, "/desfazer"
  end
  def test_the_month_shows_the_installments_as_their_own_block
    @factory.seed_user
    send_text("1200 em 12x uber mensal")
    send_text("35 mercado")

    reply = send_text("/mes")

    assert_includes reply.text, "Parcelas"
    assert_includes reply.text, "uber mensal 1/12"
    assert_includes reply.text, "R$ 100,00"
  end
end
