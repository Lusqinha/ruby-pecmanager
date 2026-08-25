# frozen_string_literal: true

require_relative "../test_helper"

class CategorizerTest < Minitest::Test
  def categories
    [Domain::Category.new(id: 1, name: "Mercado", keywords: %w[mercado feira padaria]),
     Domain::Category.new(id: 2, name: "Saúde", keywords: %w[farmacia remedio]),
     Domain::Category.new(id: 3, name: "Transporte", keywords: %w[uber gasolina])]
  end

  def resolve(hint) = Domain::Categorizer.resolve(categories, hint)

  def test_matches_by_name_ignoring_accents_and_case
    assert_equal "Saúde", resolve("saude").name
    assert_equal "Mercado", resolve("MERCADO").name
  end

  def test_matches_by_keyword
    assert_equal "Transporte", resolve("uber").name
    assert_equal "Saúde", resolve("farmácia").name
  end

  def test_matches_a_keyword_inside_a_phrase
    assert_equal "Mercado", resolve("compras na padaria da esquina").name
  end

  def test_returns_nil_without_a_match
    assert_nil resolve("presente de aniversário")
    assert_nil resolve("")
    assert_nil resolve(nil)
  end

  # Dois estabelecimentos com a mesma primeira palavra: só a frase inteira
  # decide, e a ordem da lista não pode desempatar.
  def merchants
    [Domain::Category.new(id: 1, name: "Compras", keywords: ["supermercado bagatoli"]),
     Domain::Category.new(id: 2, name: "Alimentação", keywords: ["supermercado jepsen"])]
  end

  def test_matches_a_keyword_made_of_several_words
    assert_equal "Alimentação", Domain::Categorizer.resolve(merchants, "Supermercado Jepsen").name
    assert_equal "Compras", Domain::Categorizer.resolve(merchants, "supermercado bagatoli 68").name
  end

  def test_a_partial_phrase_does_not_match
    assert_nil Domain::Categorizer.resolve(merchants, "supermercado")
    assert_nil Domain::Categorizer.resolve(merchants, "padaria do bairro")
  end
end
