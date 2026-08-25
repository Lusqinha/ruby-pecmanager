# frozen_string_literal: true

module Features
  module Installments
    # "1200 em 12x notebook" e "12x de 100 notebook" são a mesma compra dita de
    # dois jeitos. A posição do valor decide o significado: antes do "12x" é o
    # total, depois é o valor da parcela.
    module TextInput
      COUNT = /(\d{1,2})\s*x\b/i
      AMOUNT = /(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i
      MONTHS = %w[jan fev mar abr mai jun jul ago set out nov dez].freeze
      STARTS = /(?:a partir de|a partir do|come[çc]ando em|desde|em)/i
      MONTH_NAME = /\b#{STARTS}\s+(#{MONTHS.join('|')})[a-zç]*\b/i
      MONTH_NUMERIC = %r{\b#{STARTS}\s+(\d{1,2})/(\d{4})\b}i
      NOISE = /\b(?:em|de|do|da|no|na|com|pra|para|por|vezes|parcelas?|reais?|r\$)\b/i

      module_function

      def match?(text) = !COUNT.match(text.to_s).nil?

      def parse(text, today: Date.today)
        text = text.to_s.strip
        return nil unless COUNT.match?(text)

        rest, first_month = extract_month(text, today)
        count_match = COUNT.match(rest)
        return nil unless count_match

        count = count_match[1].to_i
        return nil unless count.positive?

        amount, position, rest = extract_amount(rest, count_match)
        return nil unless amount&.positive?

        { total: position == :before ? amount : amount * count, count: count,
          first_month: first_month, description: cleanup(rest) }
      end

      def extract_month(text, today)
        if (match = MONTH_NUMERIC.match(text))
          return [text.sub(match[0], " "), Date.new(match[2].to_i, match[1].to_i, 1)]
        end

        if (match = MONTH_NAME.match(text))
          month = MONTHS.index(match[1].downcase[0, 3]) + 1
          # Mês já passado neste ano quer dizer o ano que vem.
          year = month < today.month ? today.year + 1 : today.year
          return [text.sub(match[0], " "), Date.new(year, month, 1)]
        end

        [text, Domain::Month.first_of(today)]
      end

      # Valor antes do "12x" é o total da compra; depois, é o valor da parcela.
      def extract_amount(text, count_match)
        head = text[0...count_match.begin(0)].to_s
        tail = text[count_match.end(0)..].to_s

        if (match = AMOUNT.match(head))
          [Interface::MoneyParser.parse(match[0]), :before, "#{head.sub(match[0], ' ')} #{tail}"]
        elsif (match = AMOUNT.match(tail))
          [Interface::MoneyParser.parse(match[0]), :after, "#{head} #{tail.sub(match[0], ' ')}"]
        else
          [nil, nil, text]
        end
      end

      def cleanup(text)
        text.gsub(COUNT, " ").gsub(NOISE, " ").gsub(/[^\p{L}\p{N}\s]/, " ").squeeze(" ").strip
      end
    end
  end
end
