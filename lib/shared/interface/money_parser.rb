# frozen_string_literal: true

module Interface
  # Accepts pt-BR ("1.200,50") and the US notation people paste out of habit.
  module MoneyParser
    module_function

    def parse(text)
      return nil if text.nil?

      match = text.to_s.downcase.delete("r$").match(/(\d[\d.,\s]*)/)
      return nil unless match

      raw = match[1].gsub(/\s/, "").sub(/[.,]+\z/, "")
      return nil if raw.empty?

      units, decimals = split_decimal(raw)
      return nil if units.empty?

      Domain::Money.new(units.to_i * 100 + decimals.ljust(2, "0")[0, 2].to_i)
    end

    # "1.200" is a thousands separator in pt-BR, "12.50" is a US decimal
    # point. Three trailing digits is the tell. A comma is always decimal.
    def split_decimal(raw)
      has_dot = raw.include?(".")
      has_comma = raw.include?(",")

      if has_dot && has_comma
        separator = raw.rindex(",") > raw.rindex(".") ? "," : "."
        cut(raw.delete(separator == "," ? "." : ","), separator)
      elsif has_comma then cut(raw, ",")
      elsif has_dot then raw.split(".").last.size == 3 ? [raw.delete("."), ""] : cut(raw, ".")
      else [raw, ""]
      end
    end

    def cut(raw, separator)
      units, decimals = raw.split(separator, 2)
      [units.to_s, decimals.to_s]
    end
  end
end
