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

  # A assinatura cadastrada não gera lançamento, mas ocupa o teto igual.
  def test_the_month_counts_the_subscriptions_in_their_category
    @factory.categories.replace_all(3, [Domain::Category.new(name: "Assinaturas",
                                                             limit: Domain::BudgetLimit.fixed(money(20_000)))])
    @factory.subscriptions.replace_all(3, [Domain::Subscription.new(name: "Netflix", amount: money(4_000))])

    reply = send_text("/mes")

    assert_includes reply.text, "Assinaturas: ██░░░░░░░░ R$ 40,00/R$ 200,00 (20%)"
    assert_includes reply.text, "(no budget)"
    assert_includes send_text("/categoria assinaturas").text, "Inclui R$ 40,00 de assinaturas"
  end

  def test_the_month_can_be_asked_by_name_and_walked_with_the_buttons
    reply = send_text("/mes out/26")

    assert_includes reply.text, "*10/2026* — previsão"
    assert_equal [["◀ 09/26", "month:2026-09"], ["11/26 ▶", "month:2026-11"]], reply.keyboard.flatten(1)
    assert_includes tap_button("month:2026-11").text, "*11/2026*"
    assert_includes send_text("/mes banana").text, "Não entendi o mês"
  end

  # A parcela marcada para um mês futuro aparece nele, mesmo sem gasto nenhum.
  def test_a_future_month_shows_the_installments_already_booked
    send_text("1200 em 12x uber mensal")

    assert_includes send_text("/mes 12/2026").text, "uber mensal 5/12"
  end

  def test_the_month_suggests_how_to_split_the_leftover_between_the_boxes
    @factory.goals.replace_all(3, [
                                 Domain::Goal.new(name: "reserva", target: money(1_000_000),
                                                  deadline: Date.new(2028, 1, 1)),
                                 Domain::Goal.new(name: "notebook", target: money(500_000),
                                                  deadline: Date.new(2027, 1, 1))
                               ])

    reply = send_text("/mes")

    # Sobra de 3.500,00 com os tetos cheios: 90% para o prazo mais curto.
    assert_includes reply.text, "*Guardar em 08/2026* — R$ 3.500,00"
    assert_includes reply.text, "· *notebook*: R$ 3.150,00 — prioridade, prazo 01/2027"
    assert_includes reply.text, "· *reserva*: R$ 350,00"
  end

  def test_a_tight_month_suggests_moving_quota_between_the_categories
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "urgente", target: money(500_000),
                                                    deadline: Date.new(2026, 9, 1))])

    reply = send_text("/mes")

    assert_includes reply.text, "*Remanejo sugerido* — faltam R$ 1.500,00"
    assert_includes reply.text, "· *Transporte*: R$ 1.000,00 → R$ 0,00"
    assert_includes reply.text, "· *Mercado*: R$ 500,00 → R$ 0,00"
  end

  # Mês futuro não tem gasto nenhum: toda categoria pareceria folgada.
  def test_a_future_month_does_not_suggest_a_rebalance
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "urgente", target: money(500_000),
                                                    deadline: Date.new(2026, 9, 1))])

    refute_includes send_text("/mes 12/2026").text, "Remanejo"
  end

  def test_the_chart_command_offers_every_option
    @factory.seed_user

    reply = send_text("/grafico")

    assert_equal [["Categorias", "chart:categories"], ["Gastos mês a mês", "chart:months"],
                  ["Caixinhas", "chart:boxes"], ["Acumulado da projeção", "chart:accumulated"]],
                 reply.keyboard.flatten(1)
  end
end
