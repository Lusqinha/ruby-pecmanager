# frozen_string_literal: true

module Domain
  class Category
    attr_reader :id, :user_id, :name, :keywords, :limit

    def initialize(name:, id: nil, user_id: nil, keywords: [], limit: BudgetLimit.none)
      @id = id
      @user_id = user_id
      @name = name
      @keywords = keywords.map { |k| k.to_s.strip.downcase }.reject(&:empty?).uniq
      @limit = limit
    end

    def budget_for(salary) = limit.cents_for(salary)

    def with_limit(new_limit)
      self.class.new(id: id, user_id: user_id, name: name, keywords: keywords, limit: new_limit)
    end

    def with_keyword(word)
      word = word.to_s.strip.downcase
      return self if word.empty? || keywords.include?(word)

      self.class.new(id: id, user_id: user_id, name: name, keywords: keywords + [word], limit: limit)
    end
  end
end
