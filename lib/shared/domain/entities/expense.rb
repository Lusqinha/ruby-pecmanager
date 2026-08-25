# frozen_string_literal: true

module Domain
  class Expense
    SOURCES = %w[llm regex manual].freeze
    UNDO_WINDOW_SECONDS = 300

    attr_reader :id, :user_id, :category_id, :amount, :description, :spent_on, :source, :created_at

    def initialize(user_id:, amount:, spent_on:, id: nil, category_id: nil, description: "",
                   source: "manual", created_at: nil)
      @id = id
      @user_id = user_id
      @category_id = category_id
      @amount = amount
      @description = description.to_s
      @spent_on = spent_on
      @source = source
      @created_at = created_at
    end

    def categorized? = !category_id.nil?

    # The undo window is measured against the recorded time, so it survives a
    # restart of the bot.
    def undoable_at?(now)
      return true if created_at.nil?

      now - created_at <= UNDO_WINDOW_SECONDS
    end

    def in_category(category_id)
      self.class.new(id: id, user_id: user_id, category_id: category_id, amount: amount,
                     description: description, spent_on: spent_on, source: source, created_at: created_at)
    end

    def first_word = description.split.first
  end
end
