# frozen_string_literal: true

require "json"

module Features
  module Imports
    # O JSON que o usuário cola no chat, vindo de qualquer LLM externa. Formato
    # único: o que separa gasto de parcelamento é a presença de `parcela` e
    # `parcelas` na linha, e um lote misturado é recusado pra que cada comando
    # de import continue significando uma coisa só.
    module Payload
      Item = Struct.new(:date, :description, :amount, :number, :count, :category_hint, keyword_init: true) do
        def installment? = !count.nil?

        # "6/12" em agosto quer dizer que a primeira parcela caiu em março.
        def first_month = installment? ? Domain::Month.advance(date, -(number - 1)) : nil

        def total = installment? ? amount * count : amount
      end

      Result = Struct.new(:kind, :source, :items, :error, keyword_init: true)

      module_function

      def parse(raw)
        data = JSON.parse(raw.to_s, symbolize_names: true)
        return failure(:invalid_json) unless data.is_a?(Hash)

        lines = data[:lancamentos]
        return failure(:empty) unless lines.is_a?(Array) && lines.any?

        items = lines.map { |line| item(line) }
        return failure(:invalid_item) if items.any?(&:nil?)

        classify(items, data[:fonte])
      rescue JSON::ParserError
        failure(:invalid_json)
      end

      def classify(items, source)
        kinds = items.map(&:installment?).uniq
        return failure(:mixed) if kinds.size > 1

        Result.new(kind: kinds.first ? :installments : :expenses, source: source&.to_s, items: items)
      end

      def item(line)
        return nil unless line.is_a?(Hash)

        date = date_for(line[:data])
        amount = amount_for(line[:valor])
        description = line[:descricao].to_s.strip
        return nil if date.nil? || amount.nil? || !amount.positive? || description.empty?

        installment(line, date, amount, description)
      end

      def installment(line, date, amount, description)
        number = line[:parcela]
        count = line[:parcelas]
        base = { date: date, description: description[0, 120], amount: amount,
                 category_hint: line[:categoria]&.to_s }
        return Item.new(**base) if number.nil? && count.nil?
        return nil unless valid_numbers?(number, count)

        Item.new(**base, number: number.to_i, count: count.to_i)
      end

      def valid_numbers?(number, count)
        number.is_a?(Integer) && count.is_a?(Integer) && number.positive? && number <= count
      end

      # Aceita "68,19" e 68.19: quem gerou o JSON foi outra LLM, e as duas formas
      # aparecem na prática.
      def amount_for(value)
        case value
        when String then Interface::MoneyParser.parse(value)
        when Numeric then Domain::Money.new((value * 100).round)
        end
      end

      def date_for(value)
        Date.parse(value.to_s)
      rescue StandardError
        nil
      end

      def failure(error) = Result.new(error: error, items: [])
    end
  end
end
