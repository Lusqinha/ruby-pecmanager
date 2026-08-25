# frozen_string_literal: true

require_relative "../../test_helper"

class ImportPayloadTest < Minitest::Test
  Payload = Features::Imports::Payload

  def parse(json) = Payload.parse(json)

  def gasto = %({"fonte":"Nubank","lancamentos":[{"data":"2026-08-23","descricao":"Supermercado Jepsen","valor":"68,19"}]})

  def parcela
    %({"fonte":"Nubank","lancamentos":[{"data":"2026-08-09","descricao":"Levydossantosda","valor":"175,00","parcela":6,"parcelas":12}]})
  end

  def test_reads_a_plain_expense
    result = parse(gasto)
    item = result.items.first

    assert_equal :expenses, result.kind
    assert_equal "Nubank", result.source
    assert_equal 6_819, item.amount.cents
    assert_equal Date.new(2026, 8, 23), item.date
    assert_equal "Supermercado Jepsen", item.description
    refute item.installment?
  end

  def test_reads_an_installment_and_walks_the_start_month_back
    item = parse(parcela).items.first

    assert_equal :installments, parse(parcela).kind
    assert item.installment?
    assert_equal 17_500, item.amount.cents
    # 6/12 em agosto: a primeira caiu em março
    assert_equal Date.new(2026, 3, 1), item.first_month
    assert_equal 210_000, item.total.cents
  end

  def test_accepts_a_numeric_value
    item = parse(%({"lancamentos":[{"data":"2026-08-23","descricao":"x","valor":68.19}]})).items.first

    assert_equal 6_819, item.amount.cents
  end

  def test_refuses_a_mixed_payload
    mixed = %({"lancamentos":[{"data":"2026-08-23","descricao":"a","valor":"10,00"},) +
            %({"data":"2026-08-23","descricao":"b","valor":"10,00","parcela":1,"parcelas":2}]})

    assert_equal :mixed, parse(mixed).error
  end

  def test_refuses_broken_input
    assert_equal :invalid_json, parse("não é json").error
    assert_equal :empty, parse(%({"lancamentos":[]})).error
    assert_equal :invalid_item, parse(%({"lancamentos":[{"descricao":"sem data","valor":"1,00"}]})).error
    assert_equal :invalid_item, parse(%({"lancamentos":[{"data":"2026-08-23","descricao":"x","valor":"0"}]})).error
    assert_equal :invalid_item, parse(%({"lancamentos":[{"data":"x","descricao":"y","valor":"1,00"}]})).error
  end

  def test_refuses_an_impossible_instalment_number
    json = %({"lancamentos":[{"data":"2026-08-09","descricao":"x","valor":"10,00","parcela":13,"parcelas":12}]})

    assert_equal :invalid_item, parse(json).error
  end
end
