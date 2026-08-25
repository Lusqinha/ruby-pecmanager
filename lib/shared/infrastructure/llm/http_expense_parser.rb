# frozen_string_literal: true

require "json"
require "net/http"
require "uri"
require "date"

module Infrastructure
  module Llm
    # A new provider only has to say where to post, what to send, and where the
    # JSON hides in the answer.
    #
    # Best-effort by contract: any failure returns nil and the fallback parser
    # answers instead, because a person is waiting in a chat.
    class HttpExpenseParser
      FIELDS = %w[amount description category_hint date].freeze

      def initialize(base_url:, model:, timeout: 8, logger: Infrastructure::Log.for("llm"))
        @base_url = base_url
        @model = model
        @timeout = timeout
        @logger = logger
      end

      def parse(text, today: Date.today, categories: [])
        data = request(text, today, categories)
        return nil unless data

        amount = Interface::MoneyParser.parse(data["amount"])
        return nil unless amount&.positive?

        Ports::ParsedExpense.new(
          amount: amount, description: data["description"].to_s.strip,
          category_hint: data["category_hint"].to_s.strip,
          spent_on: parse_date(data["date"], today), source: "llm"
        )
      end

      def endpoint = raise(NotImplementedError, "#{self.class}#endpoint")

      def payload_for(_text, _today, _categories) = raise(NotImplementedError, "#{self.class}#payload_for")

      # Where the model's JSON sits inside the provider's response body.
      def extract(_body) = raise(NotImplementedError, "#{self.class}#extract")

      # Providers that keep models in memory override this.
      def warmup = true

      protected

      attr_reader :base_url, :model, :timeout, :logger

      # Deliberately short: on a CPU-only host, processing the prompt costs more
      # than generating the answer.
      def system_prompt(today, categories = [])
        hint = if categories.empty?
                 "uma palavra"
               else
                 "só o nome de uma destas: #{categories.join('; ')}"
               end

        "Extraia um gasto da frase. Hoje é #{today.strftime('%Y-%m-%d')}. " \
          "amount: número em reais. description: o que foi gasto, copiado da frase. " \
          "category_hint: #{hint}. date: YYYY-MM-DD. Só JSON."
      end

      def post(uri, body)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 2
        http.read_timeout = @timeout
        http.post(uri.path, JSON.generate(body), headers)
      end

      def headers = { "Content-Type" => "application/json" }

      private

      def request(text, today, categories)
        response = post(endpoint, payload_for(text, today, categories))
        return nil unless response.is_a?(Net::HTTPSuccess)

        content = extract(JSON.parse(response.body))
        content && JSON.parse(content)
      rescue StandardError => e
        @logger&.warn("Consulta ao modelo falhou, seguindo sem ela: #{e.class}: #{e.message}")
        nil
      end

      def parse_date(value, today)
        Date.parse(value.to_s)
      rescue StandardError
        today
      end
    end
  end
end
