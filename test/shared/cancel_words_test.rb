# frozen_string_literal: true

require_relative "../test_helper"

class CancelWordsTest < Minitest::Test
  CANCELS = [
    "cancela", "Cancelar", "cancele isso", "deixa quieto", "Deixa quieto!",
    "deixa pra lá", "deixa isso pra la", "esquece", "esquece isso",
    "desconsidera", "ignora", "apaga isso", "desfaz", "me enganei",
    "errei", "não era isso", "nao quero", "melhor não", "para"
  ].freeze

  # Tudo que carrega conteúdo próprio é gasto, não desistência.
  KEEPS = [
    "cancela a assinatura da netflix 55", "50 xis salada", "esquece o mercado 30",
    "apaguei 200 de multa", "nao", "/mes", "cancelamento de plano 90"
  ].freeze

  def test_reads_the_ways_of_giving_up
    CANCELS.each { |text| assert Interface::CancelWords.match?(text), "não reconheceu: #{text}" }
  end

  def test_leaves_anything_with_content_alone
    KEEPS.each { |text| refute Interface::CancelWords.match?(text), "sequestrou: #{text}" }
  end
end
