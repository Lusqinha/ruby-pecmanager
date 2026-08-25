# frozen_string_literal: true

module Domain
  # The LLM returns a hint in words, never an id: it does not know the ids and
  # would invent one. Resolving the hint to a category happens here.
  module Categorizer
    EXACT_NAME = 100
    EXACT_KEYWORD = 90
    PARTIAL_NAME = 50
    PARTIAL_KEYWORD = 40

    module_function

    def resolve(categories, hint)
      phrase = normalize(hint)
      words = phrase.split(/\s+/).reject(&:empty?)
      return nil if words.empty?

      categories.map { |category| [score(category, words, phrase), category] }
                .reject { |score, _| score.zero? }
                .max_by { |score, _| score }&.last
    end

    # Keyword com espaço ("supermercado jepsen") só vale inteira: é assim que o
    # nome de um estabelecimento vira categoria fixa depois da primeira
    # correção, sem que "supermercado" sozinho decida por todos.
    def score(category, words, phrase = words.join(" "))
      name = normalize(category.name)
      multi, single = category.keywords.map { |keyword| normalize(keyword) }
                              .partition { |keyword| keyword.include?(" ") }

      (multi.count { |keyword| phrase.include?(keyword) } * EXACT_KEYWORD) +
        words.sum { |word| word_score(word, name, single) }
    end

    def word_score(word, name, keywords)
      if name == word then EXACT_NAME
      elsif keywords.include?(word) then EXACT_KEYWORD
      elsif name.start_with?(word) || word.start_with?(name) then PARTIAL_NAME
      elsif keywords.any? { |keyword| keyword.start_with?(word) || word.start_with?(keyword) } then PARTIAL_KEYWORD
      else 0
      end
    end

    def normalize(text)
      text.to_s.unicode_normalize(:nfd).gsub(/\p{Mn}/, "").downcase
          .gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
    end
  end
end
