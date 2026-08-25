# frozen_string_literal: true

require "telegram/bot"
require "net/http"
require "uri"

module Infrastructure
  module Telegram
    # Translates Telegram updates into router calls, and ViewMessages back into
    # Telegram payloads. The only file that knows the gem exists.
    class BotRunner
      # Uma fatura em JSON não passa disso; o limite existe pra um anexo
      # qualquer não virar download de megabytes.
      MAX_DOCUMENT_BYTES = 512 * 1024
      def initialize(token:, allowed_user_ids:, controller:, logger: $stderr)
        @token = token
        @allowed_user_ids = allowed_user_ids
        @controller = controller
        @logger = logger
      end

      def run
        ::Telegram::Bot::Client.run(@token) do |bot|
          @logger.puts("[bot] rodando. usuários liberados: #{@allowed_user_ids.join(', ')}")
          bot.listen { |update| dispatch(bot, update) }
        end
      end

      private

      def dispatch(bot, update)
        case update
        when ::Telegram::Bot::Types::Message then handle_message(bot, update)
        when ::Telegram::Bot::Types::CallbackQuery then handle_callback(bot, update)
        end
      rescue StandardError => e
        # One bad update must never kill the polling loop.
        @logger.puts("[erro] #{e.class}: #{e.message}\n#{e.backtrace&.first(5)&.join("\n")}")
        chat_id = chat_id_for(update)
        bot.api.send_message(chat_id: chat_id, text: "Deu ruim aqui. Tenta de novo.") if chat_id
      end

      def handle_message(bot, message)
        return unless allowed?(message.from.id)

        text = message.text.to_s.empty? ? document_text(bot, message.document) : message.text
        return if text.to_s.empty?

        send_reply(bot, message.chat.id, @controller.handle_text(message.from.id, text, name: message.from.first_name))
      end

      # Um .json anexado vale como se tivesse sido colado: o import aceita os
      # dois caminhos e o resto do bot nem sabe que veio arquivo.
      def document_text(bot, document)
        return nil unless document && document.file_name.to_s.downcase.end_with?(".json")
        return nil if document.file_size.to_i > MAX_DOCUMENT_BYTES

        download(bot, document.file_id)
      rescue StandardError => e
        # A URL carrega o token: nunca entra no log.
        @logger.puts("[download] #{e.class}")
        nil
      end

      def download(bot, file_id)
        path = bot.api.get_file(file_id: file_id).file.file_path
        uri = URI("https://api.telegram.org/file/bot#{@token}/#{path}")
        response = Net::HTTP.get_response(uri)
        response.is_a?(Net::HTTPSuccess) ? response.body : nil
      end

      def handle_callback(bot, query)
        return unless allowed?(query.from.id)

        # Antes de despachar: o handler pode levar segundos no LLM, e se levantar
        # erro o botão ficaria girando até o Telegram desistir.
        bot.api.answer_callback_query(callback_query_id: query.id)
        reply = @controller.handle_callback(query.from.id, query.data)
        send_reply(bot, query.message.chat.id, reply)
      end

      def allowed?(user_id) = @allowed_user_ids.include?(user_id)

      def send_reply(bot, chat_id, reply)
        return if reply.nil? || reply.text.to_s.empty?

        markup = markup_for(reply.keyboard)
        bot.api.send_message(chat_id: chat_id, text: reply.text, parse_mode: "Markdown", reply_markup: markup)
      rescue ::Telegram::Bot::Exceptions::ResponseError => e
        # A category named "casa_nova" is enough to break legacy Markdown; the
        # message still has to reach the user.
        @logger.puts("[telegram] markdown falhou: #{e.message}")
        bot.api.send_message(chat_id: chat_id, text: reply.text, reply_markup: markup)
      end

      def markup_for(keyboard)
        return nil unless keyboard

        rows = keyboard.map do |row|
          row.map { |label, data| ::Telegram::Bot::Types::InlineKeyboardButton.new(text: label, callback_data: data) }
        end
        ::Telegram::Bot::Types::InlineKeyboardMarkup.new(inline_keyboard: rows)
      end

      def chat_id_for(update)
        update.respond_to?(:chat) ? update.chat&.id : update.message&.chat&.id
      end
    end
  end
end
