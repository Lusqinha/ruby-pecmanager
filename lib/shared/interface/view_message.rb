# frozen_string_literal: true

module Interface
  # Keyboard is a list of rows of [label, callback_data] pairs: no Telegram types
  # in here, so presenters stay independent of the delivery mechanism.
  ViewMessage = Struct.new(:text, :keyboard, :photo, :document, :filename, keyword_init: true) do
    def self.text(text) = new(text: text)

    # photo são os bytes de um PNG; o texto acompanha como legenda.
    def self.image(photo, caption:) = new(text: caption, photo: photo)

    # document é o conteúdo de um arquivo; o nome é o que o usuário vê ao baixar.
    def self.file(document, filename:, caption:) = new(text: caption, document: document, filename: filename)

    def photo? = !photo.nil?
    def document? = !document.nil?
  end
end
