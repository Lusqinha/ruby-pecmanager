# frozen_string_literal: true

require "date"

module Infrastructure
  module Parsing
    # The floor of the parsing chain: if the LLM is unreachable, this still books
    # the expense.
    class RegexExpenseParser
      AMOUNT = /(?:r\$\s*)?(\d{1,3}(?:\.\d{3})+(?:,\d{1,2})?|\d+(?:[.,]\d{1,2})?)/i
      WEEKDAYS = {
        "domingo" => 0, "segunda" => 1, "terca" => 2, "terça" => 2, "quarta" => 3,
        "quinta" => 4, "sexta" => 5, "sabado" => 6, "sábado" => 6
      }.freeze
      NOISE = /\b(no|na|em|de|do|da|com|pra|para|por|r\$|reais?)\b/i

      # categories: só o parser LLM usa; aqui a dica sai da própria descrição.
      def parse(text, today: Date.today, categories: [])
        text = text.to_s.strip
        match = AMOUNT.match(text)
        return nil unless match

        amount = Interface::MoneyParser.parse(match[0])
        return nil unless amount&.positive?

        rest = "#{text[0...match.begin(0)]} #{text[match.end(0)..]}"
        spent_on, rest = extract_date(rest, today)
        description = cleanup(rest)

        Ports::ParsedExpense.new(amount: amount, description: description,
                                           category_hint: description, spent_on: spent_on, source: "regex")
      end

      private

      def extract_date(text, today)
        lowered = text.downcase

        explicit_date(lowered, text, today) ||
          numbered_day(lowered, text, today) ||
          relative_day(lowered, text, today) ||
          weekday(lowered, text, today) ||
          [today, text]
      end

      def explicit_date(lowered, text, today)
        match = lowered.match(%r{\b(\d{1,2})/(\d{1,2})(?:/(\d{2,4}))?\b})
        return nil unless match

        year = match[3] ? normalize_year(match[3]) : today.year
        date = safe_date(year, match[2].to_i, match[1].to_i)
        date && [date, strip(text, match[0])]
      end

      def numbered_day(lowered, text, today)
        match = lowered.match(/\bdia\s+(\d{1,2})\b/)
        return nil unless match

        day = match[1].to_i
        date = safe_date(today.year, today.month, day)
        return nil unless date

        date = previous_month_day(today, day) if date > today
        date && [date, strip(text, match[0])]
      end

      def relative_day(lowered, text, today)
        { "anteontem" => 2, "ontem" => 1, "hoje" => 0 }.each do |word, back|
          return [today - back, strip(text, word)] if lowered.include?(word)
        end
        nil
      end

      def weekday(lowered, text, today)
        WEEKDAYS.each do |word, wday|
          next unless lowered.match?(/\b#{word}\b/)

          back = (today.wday - wday) % 7
          back = 7 if back.zero?
          return [today - back, strip(text, word)]
        end
        nil
      end

      def cleanup(text)
        text.gsub(NOISE, " ").gsub(/[^\p{L}\p{N}\s]/, " ").squeeze(" ").strip
      end

      def strip(text, fragment) = text.sub(/#{Regexp.escape(fragment)}/i, " ")

      def normalize_year(year) = year.size == 2 ? 2000 + year.to_i : year.to_i

      def safe_date(year, month, day)
        Date.valid_date?(year, month, day) ? Date.new(year, month, day) : nil
      end

      def previous_month_day(today, day)
        previous = today << 1
        safe_date(previous.year, previous.month, day)
      end
    end
  end
end
