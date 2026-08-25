# frozen_string_literal: true

require "json"
require_relative "../../test_helper"
require_relative "../../support/slice_case"

class ExportFlowTest < SliceCase
  def setup
    super
    with_regex_parser
    @factory.seed_user
  end

  def test_the_command_offers_both_formats
    reply = send_text("/exportar")

    assert_equal [["Markdown", "export:md"], ["JSON", "export:json"]], reply.keyboard.flatten(1)
  end

  def test_json_carries_the_plan_and_the_expenses
    send_text("35 mercado")

    reply = tap_button("export:json")
    data = JSON.parse(reply.document)

    assert_equal "pecman-#{TODAY.iso8601}.json", reply.filename
    assert_equal 5000.0, data.dig("renda", "salario_bruto")
    assert_equal 500.0, data["categorias"].find { |item| item["nome"] == "Mercado" }["teto"]
    assert_equal [35.0], data["lancamentos"].map { |item| item["valor"] }
    assert_equal "Mercado", data["lancamentos"].first["categoria"]
  end

  def test_markdown_carries_the_same_numbers_in_tables
    send_text("35 mercado")

    reply = tap_button("export:md")

    assert_equal "pecman-#{TODAY.iso8601}.md", reply.filename
    assert_includes reply.document, "# PecManager"
    assert_includes reply.document, "| Mercado | 500.00 | 35.00 | 465.00 | fixed |"
  end

  def test_the_export_says_where_the_subscriptions_live
    @factory.categories.replace_all(3, [Domain::Category.new(name: "Assinaturas",
                                                             limit: Domain::BudgetLimit.fixed(money(20_000)))])
    @factory.subscriptions.replace_all(3, [Domain::Subscription.new(name: "Netflix", amount: money(4_000))])

    data = JSON.parse(tap_button("export:json").document)

    assert data.dig("renda", "assinaturas_dentro_do_budget")
    assert_equal 40.0, data["categorias"].first["gasto_no_mes"]
    assert_includes tap_button("export:md").document, "ocupam o budget"
  end
end
