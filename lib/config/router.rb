# frozen_string_literal: true

module Config
  # Walks the slices in order and takes the first answer. Knows no commands:
  # every route lives in the slice that implements it.
  class Router
    UNKNOWN_BUTTON = "Botão desconhecido."

    def initialize(handlers:)
      @handlers = handlers
    end

    def handle_text(user_id, text, name: nil)
      request = Shared::Request.new(user_id: user_id, text: text.to_s.strip, name: name, callback: false)

      intercepted(request) || first { |handler| handler.handle_text(request) } ||
        first { |handler| handler.fallback(request) }
    end

    def handle_callback(user_id, data)
      request = Shared::Request.new(user_id: user_id, text: data.to_s, name: nil, callback: true)

      intercepted(request) || first { |handler| handler.handle_callback(request) } ||
        Interface::ViewMessage.text(UNKNOWN_BUTTON)
    end

    private

    def intercepted(request) = first { |handler| handler.intercept(request) }

    def first
      @handlers.each do |handler|
        result = yield(handler)
        return result if result
      end
      nil
    end
  end
end
