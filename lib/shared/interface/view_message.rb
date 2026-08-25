# frozen_string_literal: true

module Interface
  # Keyboard is a list of rows of [label, callback_data] pairs: no Telegram types
  # in here, so presenters stay independent of the delivery mechanism.
  ViewMessage = Struct.new(:text, :keyboard, :photo, keyword_init: true) do
    def self.text(text) = new(text: text)

    # photo são os bytes de um PNG; o texto acompanha como legenda.
    def self.image(photo, caption:) = new(text: caption, photo: photo)

    def photo? = !photo.nil?
  end
end
