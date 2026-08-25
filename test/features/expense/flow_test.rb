# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class ExpenseFlowTest < SliceCase
  # Estourar o teto não pode virar só um aviso: o bot diz de onde tirar a cota.
  def test_bursting_a_budget_suggests_moving_quota_from_the_roomiest_category
    with_regex_parser
    @factory.seed_user

    reply = send_text("600 mercado")

    assert_includes reply.text, "⚠️ estourou R$ 100,00 do teto de R$ 500,00"
    assert_includes reply.text, "*Remanejo sugerido para este mês* (R$ 100,00 → Mercado)"
    assert_includes reply.text, "· *Transporte*: R$ 1.000,00 → R$ 900,00 (gastou R$ 0,00)"
  end

  def test_a_booking_inside_the_budget_says_nothing_about_rebalancing
    with_regex_parser
    @factory.seed_user

    refute_includes send_text("35 mercado").text, "Remanejo"
  end

  # Conta as consultas ao modelo: o ponto é não fazer nenhuma quando o
  # determinístico já resolveu.
  class CountingParser
    attr_reader :calls

    def initialize(result = nil)
      @result = result
      @calls = 0
    end

    def parse(_text, today: nil, categories: [])
      @calls += 1
      @result
    end
  end

  def test_a_description_that_matches_a_keyword_never_reaches_the_llm
    @factory.seed_user
    counting = CountingParser.new
    @factory.parser = counting

    reply = send_text("35 mercado")

    assert_equal 0, counting.calls
    assert_includes reply.text, "restam"
    assert_equal "regex", @factory.expenses.find(3, 1).source
  end

  def test_an_unknown_description_escalates_to_the_llm
    @factory.seed_user
    counting = CountingParser.new(Ports::ParsedExpense.new(
                                    amount: money(5_000), description: "xis salada",
                                    category_hint: "mercado", spent_on: TODAY, source: "llm"
                                  ))
    @factory.parser = counting

    send_text("50 xis salada")

    assert_equal 1, counting.calls
    assert_equal "llm", @factory.expenses.find(3, 1).source
  end

  def test_falls_back_to_regex_when_the_llm_is_down
    with_regex_parser
    @factory.seed_user
    reply = send_text("35 mercado")
    expense = @factory.expenses.find(3, 1)

    assert_equal 3_500, expense.amount.cents
    assert_equal "regex", expense.source
    assert_includes reply.text, "restam"
  end

  def test_uses_the_llm_when_it_answers
    @factory.seed_user
    @factory.parser = StubParser.new(Ports::ParsedExpense.new(
                                       amount: money(8_990), description: "corrida pro aeroporto",
                                       category_hint: "uber", spent_on: TODAY - 1, source: "llm"
                                     ))

    send_text("gastei 89,90 numa corrida pro aeroporto ontem")
    expense = @factory.expenses.find(3, 1)

    assert_equal "llm", expense.source
    assert_equal TODAY - 1, expense.spent_on
    assert_equal "Transporte", @factory.categories.find(3, expense.category_id).name
  end

  def test_sends_the_categories_with_their_keywords_to_the_parser
    @factory.seed_user
    @factory.parser = StubParser.new
    send_text("50 xis salada")

    assert_equal ["Mercado (mercado, feira)", "Transporte (uber)"], @factory.parser.seen_categories
  end

  def test_unparseable_text_books_nothing
    with_regex_parser
    @factory.seed_user
    reply = send_text("bom dia")

    assert_empty @factory.expenses.rows
    assert_includes reply.text, "Não identifiquei"
  end

  def test_unmatched_category_asks_and_learns_from_the_answer
    with_regex_parser
    @factory.seed_user
    reply = send_text("120 presente de aniversario")
    expense = @factory.expenses.find(3, 1)

    refute expense.categorized?
    assert_includes reply.text, "Em qual categoria"

    target = @factory.categories.for_user(3).first
    tap_button("cat:#{expense.id}:#{target.id}")

    assert_equal target.id, @factory.expenses.find(3, expense.id).category_id
    assert_includes @factory.categories.find(3, target.id).keywords, "presente"
  end

  def test_change_category_button_offers_the_list
    with_regex_parser
    @factory.seed_user
    send_text("35 mercado")

    reply = tap_button("chg:1")

    assert_includes reply.text, "Em qual categoria"
    assert_equal 1, reply.keyboard.size
  end

  def test_undo_within_the_window
    with_regex_parser
    @factory.seed_user
    send_text("35 mercado")

    reply = tap_button("undo:1")

    assert_includes reply.text, "Desfeito"
    assert_empty @factory.expenses.rows
  end

  def test_undo_command_removes_the_last_one
    with_regex_parser
    @factory.seed_user
    send_text("35 mercado")
    send_text("20 uber")

    send_text("/desfazer")

    assert_equal 1, @factory.expenses.rows.size
  end

  def test_plain_words_undo_the_last_expense
    with_regex_parser
    @factory.seed_user
    send_text("35 mercado")

    reply = send_text("deixa quieto")

    assert_includes reply.text, "Desfeito"
    assert_empty @factory.expenses.rows
  end

  def test_a_sentence_with_content_stays_an_expense
    with_regex_parser
    @factory.seed_user

    send_text("cancela a assinatura 55")

    assert_equal 1, @factory.expenses.rows.size
  end

  def test_undo_refused_after_the_window
    with_regex_parser
    @factory.seed_user
    send_text("35 mercado")
    @clock.now = NOW + 600

    reply = tap_button("undo:1")

    assert_includes reply.text, "prazo de 5 minutos"
    assert_equal 1, @factory.expenses.rows.size
  end

  def test_another_user_cannot_touch_an_expense
    with_regex_parser
    @factory.seed_user
    @factory.seed_user(id: 4, categories: [["Mercado", %w[mercado]]])
    send_text("35 mercado")

    reply = tap_button("undo:1", user_id: 4)

    # The reply does not confirm that someone else's expense exists.
    assert_includes reply.text, "Não há lançamento recente"
    assert_equal 1, @factory.expenses.rows.size
  end
  # 20% de 5.000 seria 1.000; com 6% de dedução o líquido é 4.700 e o teto cai
  # pra 940. É o número que o usuário vê ao lançar.
  def test_a_percentage_budget_comes_out_of_the_net_income
    @factory.seed_user
    @factory.categories.replace_all(3, [Domain::Category.new(name: "Mercado", keywords: %w[mercado],
                                                             limit: Domain::BudgetLimit.percent(20))])
    @factory.fixed_costs.replace_all(3, [Domain::FixedCost.new(name: "Imposto", amount: Domain::Money.new(600),
                                                               kind: "pct", deduction: true)])

    reply = send_text("40 mercado")

    assert_includes reply.text, "R$ 940,00"
  end
end
