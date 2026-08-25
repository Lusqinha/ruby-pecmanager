# frozen_string_literal: true

module Shared
  Request = Struct.new(:user_id, :text, :name, :callback, keyword_init: true) do
    def callback? = !!callback
  end

  # Routes are declared inside the slice itself, so adding a command means
  # touching one feature folder and never the router:
  #
  #   route "/mes", to: :monthly
  #   callback(/\Aundo:(\d+)\z/, to: :undo)
  #   fallback :record
  class Handler
    class << self
      def text_routes = @text_routes ||= []
      def callback_routes = @callback_routes ||= []
      def fallback_action = @fallback_action

      def route(pattern, to:) = text_routes << [pattern, to]
      def callback(pattern, to:) = callback_routes << [pattern, to]
      def fallback(action) = @fallback_action = action
    end

    def handle_text(request)
      dispatch(self.class.text_routes, request.text, request)
    end

    def handle_callback(request)
      dispatch(self.class.callback_routes, request.text, request)
    end

    # Overridden by slices that swallow every message while a conversation is
    # open, like the setup wizard.
    def intercept(_request) = nil

    def fallback(request)
      action = self.class.fallback_action
      action && public_send(action, request)
    end

    private

    def dispatch(routes, text, request)
      routes.each do |pattern, action|
        captures = match(pattern, text.to_s.strip)
        next unless captures

        return public_send(action, request, *captures)
      end
      nil
    end

    def match(pattern, text)
      case pattern
      when Regexp then (found = pattern.match(text)) && found.captures
      when String then pattern.casecmp?(text) ? [] : nil
      # Qualquer objeto que saiba dizer se a mensagem é dele, como CancelWords.
      else pattern.match?(text) ? [] : nil
      end
    end
  end
end
