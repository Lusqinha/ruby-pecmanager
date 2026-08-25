# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class ImportFlowTest < SliceCase
  def parcelas
    %({"fonte":"Nubank","lancamentos":[
      {"data":"2026-08-09","descricao":"Levydossantosda","valor":"175,00","parcela":6,"parcelas":12},
      {"data":"2026-08-09","descricao":"Clinrad Clinica","valor":"187,15","parcela":6,"parcelas":10}]})
  end

  def gastos
    %({"fonte":"Nubank","lancamentos":[
      {"data":"2026-08-23","descricao":"Supermercado Jepsen","valor":"68,19","categoria":"Mercado"},
      {"data":"2026-08-16","descricao":"Uber para o centro","valor":"22,90"}]})
  end

  def test_the_prompt_carries_the_users_own_categories_and_keywords
    @factory.seed_user

    reply = send_text("/importar_parcelas")

    assert_includes reply.text, "- Mercado: mercado, feira"
    assert_includes reply.text, "parcelas"
  end

  def test_nothing_is_recorded_before_confirming
    @factory.seed_user

    reply = send_text(parcelas)

    assert_includes reply.text, "Levydossantosda 6/12"
    assert_includes reply.text, "03/2026"
    assert_empty @factory.installment_plans.for_user(3)
    assert_includes reply.text, "consumir o budget"
    assert_equal [["Contar no budget", "import:budget"], ["Fora do budget", "import:free"],
                  ["Descartar", "import:no"]], reply.keyboard.flatten(1)
  end

  def test_confirming_records_the_plans_with_the_start_month_walked_back
    @factory.seed_user
    send_text(parcelas)

    reply = tap_button("import:free")
    plans = @factory.installment_plans.for_user(3)

    assert_equal 2, plans.size
    assert_equal Date.new(2026, 3, 1), plans.first.first_month
    assert_equal 210_000, plans.first.total.cents
    assert_equal "Nubank", plans.first.origin
    assert_includes reply.text, "2 lançado"
  end

  def test_discarding_keeps_the_books_untouched
    @factory.seed_user
    send_text(parcelas)

    tap_button("import:no")

    assert_empty @factory.installment_plans.for_user(3)
    assert_includes tap_button("import:ok").text, "Nenhuma importação"
  end

  def test_importing_the_same_invoice_again_finds_the_duplicates
    @factory.seed_user
    send_text(parcelas)
    tap_button("import:free")

    reply = send_text(parcelas)

    assert_includes reply.text, "já estavam lançados"
    assert_equal 2, @factory.installment_plans.for_user(3).size
  end

  def test_expenses_use_the_keyword_first_and_the_hint_as_fallback
    @factory.seed_user
    send_text(gastos)
    tap_button("import:ok")

    expenses = @factory.expenses.rows.values
    jepsen = expenses.find { |item| item.description.include?("Jepsen") }
    uber = expenses.find { |item| item.description.include?("Uber") }

    assert_equal "Mercado", @factory.categories.find(3, jepsen.category_id).name
    assert_equal "Transporte", @factory.categories.find(3, uber.category_id).name
    assert_equal "import", uber.source
  end

  def test_a_mixed_batch_is_refused
    @factory.seed_user
    mixed = %({"lancamentos":[{"data":"2026-08-23","descricao":"a","valor":"10,00"},) +
            %({"data":"2026-08-23","descricao":"b","valor":"10,00","parcela":1,"parcelas":2}]})

    reply = send_text(mixed)

    assert_includes reply.text, "Separe em dois arquivos"
    assert_empty @factory.expenses.rows
  end
  def test_choosing_out_of_the_budget_skips_categorization
    @factory.seed_user
    send_text(parcelas)

    reply = tap_button("import:free")

    refute @factory.users.find(3).installments_in_budget?
    assert(@factory.installment_plans.for_user(3).all? { |plan| plan.category_id.nil? })
    assert_includes reply.text, "fora do budget"
  end

  def test_choosing_the_budget_categorizes_and_remembers_the_answer
    @factory.seed_user
    send_text(%({"lancamentos":[{"data":"2026-08-09","descricao":"uber mensal","valor":"100,00","parcela":1,"parcelas":12}]}))

    reply = tap_button("import:budget")
    plan = @factory.installment_plans.for_user(3).first

    assert @factory.users.find(3).installments_in_budget?
    assert_equal "Transporte", @factory.categories.find(3, plan.category_id).name
    assert_includes reply.text, "budget"
  end
end
