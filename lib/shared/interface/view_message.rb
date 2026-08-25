# frozen_string_literal: true

module Interface
  # Keyboard is a list of rows of [label, callback_data] pairs: no Telegram types
  # in here, so presenters stay independent of the delivery mechanism.
  ViewMessage = Struct.new(:text, :keyboard, keyword_init: true) do
    def self.text(text) = new(text: text)
  end
end
