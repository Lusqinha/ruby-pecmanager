# frozen_string_literal: true

module Interface
  # "cancela", "deixa quieto", "me enganei": desistir escrito como se fala, sem
  # comando com barra. Reconhecer isso é do texto, não da feature: o setup lê
  # como abortar o wizard e o gasto lê como desfazer o último lançamento.
  module CancelWords
    WORDS = /(?:cancel(?:a|ar|e|em)?|desfaz(?:er)?|desfaca|esquece[r]?|desconsidera[r]?|ignora[r]?|
              apaga[r]?|deleta[r]?|remove[r]?|para|deixa\squieto|deixa\s(?:isso\s)?pra\sla|
              deixa\s(?:isso\s)?de\slado|nao\squero|nao\sera\s(?:isso|esse|essa)|me\senganei|
              errei|foi\sengano|melhor\snao)/x
    # Só complemento vazio de significado: o que muda a frase (um valor, um
    # item) tem de escapar daqui e seguir como gasto.
    TAIL = /(?:\s(?:isso|isto|esse|essa|este|tudo|ai|entao|por\sfavor|o|a|gasto|lancamento|
                    operacao|conta))*/x
    PATTERN = /\A#{WORDS}#{TAIL}\z/

    # A mensagem inteira tem de ser o pedido: "cancela a assinatura 55" é um
    # gasto, não um cancelamento.
    def self.match?(text) = PATTERN.match?(Domain::Categorizer.normalize(text))
  end
end
