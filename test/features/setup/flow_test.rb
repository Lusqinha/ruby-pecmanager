# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class SetupFlowTest < SliceCase
  def test_first_contact_asks_how_the_money_arrives
    reply = send_text("oi")

    assert_includes reply.text, "Passo 1/8"
    assert_equal [["Sou PJ", "pj"], ["Sou CLT", "clt"]], reply.keyboard.flatten(1)
  end

  def test_pj_and_clt_get_different_wording
    send_text("oi")

    assert_includes tap_button("pj").text, "antes dos impostos"

    send_text("/cancelar")
    send_text("oi")

    assert_includes tap_button("clt").text, "cai na sua conta"
  end

  def test_the_deductions_step_marks_everything_as_a_deduction
    send_text("oi")
    tap_button("pj")
    send_text("4200")
    send_text("imposto 6%\ninss 178,31\ncontabilidade 250")

    draft = @factory.drafts.find(3)[:draft]
    imposto = draft.deductions.find { |item| item.name.casecmp?("imposto") }

    assert_equal 3, draft.deductions.size
    assert(draft.deductions.all?(&:deduction?))
    assert imposto.percent?
    assert_equal 600, imposto.amount.cents
    # 6% de 4.200 = 252,00
    assert_equal 25_200, imposto.monthly_amount(draft.salary).cents
  end

  def test_the_wizard_swallows_everything_while_it_is_open
    send_text("oi")
    tap_button("clt")
    reply = send_text("/mes") # not a report: the wizard owns the conversation

    assert_includes reply.text, "Passo 2/8"
    assert_includes reply.text, "Não peguei o valor"
  end

  def test_fixed_costs_accept_percentage_deductions
    send_text("oi", user_id: 9, name: "Lucas")
    tap_button("pj", user_id: 9)
    send_text("4200", user_id: 9)
    send_text("pronto", user_id: 9)
    tap_button("preset", user_id: 9)
    Features::Setup::Presets.size.times { send_text("10%", user_id: 9) }
    send_text("imposto 6% dedução\ncontabilidade 250 dedução\naluguel 900 dia 10", user_id: 9)
    send_text("pronto", user_id: 9)
    send_text("pronto", user_id: 9)
    send_text("pronto", user_id: 9)
    tap_button("confirmar", user_id: 9)

    costs = @factory.fixed_costs.for_user(9).to_h { |item| [item.name.downcase, item] }

    assert costs["imposto"].percent?
    assert costs["imposto"].deduction?
    assert_equal 600, costs["imposto"].amount.cents
    assert costs["contabilidade"].deduction?
    refute costs["aluguel"].deduction?
    assert_equal 10, costs["aluguel"].due_day
  end

  def test_full_setup_writes_every_repository
    user = run_setup

    assert user.setup_done?
    assert_equal 500_000, user.salary.cents
    assert_equal Features::Setup::Presets.size, @factory.categories.for_user(7).size
    assert_equal 120_000, @factory.fixed_costs.for_user(7).first.amount.cents
    assert_equal 10, @factory.fixed_costs.for_user(7).first.due_day
    assert_equal Domain::Subscription::MONTHLY, @factory.subscriptions.for_user(7).first.cycle
    assert_equal Date.new(2027, 12, 1), @factory.goals.for_user(7).first.deadline
    assert_nil @factory.drafts.find(7)
  end

  def test_invalid_salary_repeats_the_step
    send_text("oi")
    tap_button("clt")
    reply = send_text("muito dinheiro")

    assert_includes reply.text, "Não peguei o valor"
    assert_equal :salary, @factory.drafts.find(3)[:step]
  end

  def test_confirmation_warns_about_overcommitted_budgets
    send_text("oi")
    tap_button("clt")
    send_text("5000")
    send_text("pronto")
    tap_button("preset")
    Features::Setup::Presets.size.times { send_text("20%") }
    3.times { send_text("pronto") }
    reply = send_text("pronto")

    assert_includes reply.text, "estouram"
  end

  def test_setup_resumes_from_a_fresh_router
    send_text("oi")
    tap_button("clt")
    send_text("5000")
    send_text("pronto")

    reply = @factory.router.handle_callback(3, "preset")

    assert_includes reply.text, "Budget"
  end

  def test_cancel_wipes_the_draft
    send_text("oi")
    send_text("/cancelar")

    assert_nil @factory.drafts.find(3)
  end

  def test_giving_up_in_plain_words_wipes_the_draft
    send_text("oi")
    send_text("esquece isso")

    assert_nil @factory.drafts.find(3)
  end

  def test_rerunning_setup_keeps_categories_that_have_history
    with_regex_parser
    run_setup
    send_text("35 mercado", user_id: 7)

    send_text("/setup", user_id: 7)
    tap_button("clt", user_id: 7)
    send_text("6000", user_id: 7)
    send_text("pronto", user_id: 7)
    send_text("lazer", user_id: 7)
    send_text("10%", user_id: 7)
    3.times { send_text("pronto", user_id: 7) }
    tap_button("confirmar", user_id: 7)

    names = @factory.categories.for_user(7).map(&:name)

    assert_includes names, "Lazer"
    assert_includes names, "Mercado"
    refute_includes names, "Educação"
    assert_equal 600_000, @factory.users.find(7).salary.cents
  end
  # Botão de uma tela anterior não pode virar resposta do passo aberto.
  def test_a_stale_button_is_not_read_as_an_answer
    send_text("oi")
    tap_button("clt")

    reply = tap_button("undo:1200")

    assert_includes reply.text, "Passo 2/8"
    assert_nil @factory.drafts.find(3)[:draft].salary
  end
end
