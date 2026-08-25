# frozen_string_literal: true

module Features
  module Setup
    # Not presentation: these names end up stored as the user's own categories.
    module Presets
      ITEMS = [
        { name: "Mercado", keywords: %w[mercado supermercado feira padaria acougue] },
        { name: "Transporte", keywords: %w[uber gasolina onibus metro combustivel taxi corrida] },
        { name: "Moradia", keywords: %w[aluguel condominio luz agua internet gas] },
        { name: "Saúde", keywords: %w[farmacia remedio medico dentista exame plano] },
        { name: "Lazer", keywords: %w[bar cinema restaurante ifood viagem show] },
        { name: "Educação", keywords: %w[curso livro faculdade escola material] },
        { name: "Outros", keywords: [] }
      ].freeze

      def self.categories
        ITEMS.map { |item| Domain::Category.new(name: item[:name], keywords: item[:keywords]) }
      end

      def self.names = ITEMS.map { |item| item[:name] }
      def self.size = ITEMS.size
    end
  end
end
