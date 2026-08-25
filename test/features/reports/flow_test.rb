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
    assert_includes send_text("/categoria nao existe").text, "Categoria não encontrada"
    assert_includes send_text("/categoria").text, "Categoria não encontrada"
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
  def test_the_month_adds_the_instalment_to_the_category_when_the_option_is_on
    @factory.seed_user
    tap_button("plan:budget:on")
    send_text("1200 em 12x uber mensal")

    reply = send_text("/mes")

    # 100,00 da parcela entram na linha de Transporte
    assert_includes reply.text, "Transporte: █░░░░░░░░░ R$ 100,00/R$ 1.000,00"
  end

  def test_the_chart_comes_back_as_a_png_with_a_legend
    @factory.seed_user
    send_text("35 mercado")

    reply = tap_button("chart:categories")

    assert reply.photo?
    assert_equal "\x89PNG\r\n\x1A\n".b, reply.photo[0, 8]
    assert_includes reply.text, "1. Mercado: resta R$ 465,00 de R$ 500,00"
  end

  def test_a_month_without_movement_answers_in_text
    @factory.seed_user(categories: [])

    reply = tap_button("chart:categories")

    refute reply.photo?
    assert_includes reply.text, "Nenhuma categoria com limite"
  end
  def test_the_monthly_history_plots_one_column_per_month
    @factory.seed_user
    send_text("35 mercado")

    reply = tap_button("chart:months")

    assert reply.photo?
    assert_equal "\x89PNG\r\n\x1A\n".b, reply.photo[0, 8]
    assert_includes reply.text, "08/2026: R$ 35,00"
    # Seis meses na legenda, do mais antigo ao atual
    assert_includes reply.text, "03/2026: R$ 0,00"
  end

  def test_the_history_answers_in_text_when_there_is_nothing_yet
    @factory.seed_user

    reply = tap_button("chart:months")

    refute reply.photo?
    assert_includes reply.text, "Nenhum gasto registrado"
  end

  def test_the_chart_command_offers_the_three_options
    @factory.seed_user

    reply = send_text("/grafico")

    assert_equal [["Categorias", "chart:categories"], ["Gastos mês a mês", "chart:months"],
                  ["Caixinhas", "chart:boxes"]], reply.keyboard.flatten(1)
  end
end
