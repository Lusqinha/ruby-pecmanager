# frozen_string_literal: true

module Infrastructure
  module Llm
    class LlamaExpenseParser < HttpExpenseParser
      SCHEMA = {
        type: "object",
        properties: FIELDS.to_h { |field| [field, { type: "string" }] },
        required: FIELDS
      }.freeze

      def initialize(base_url: ENV.fetch("LLAMA_URL", "http://localhost:8080"),
                     model: ENV.fetch("LLAMA_MODEL", "qwen"),
                     timeout: Integer(ENV.fetch("LLAMA_TIMEOUT", "8")),
                     logger: Infrastructure::Log.for("llm"))
        super
      end

      def endpoint = URI.join(base_url, "/v1/chat/completions")

      def payload_for(text, today, categories = [])
        {
          model: model, temperature: 0,
          messages: [{ role: "system", content: system_prompt(today, categories) },
                     { role: "user", content: text.to_s }],
          response_format: { type: "json_schema", json_schema: { name: "expense", strict: true, schema: SCHEMA } }
        }
      end

      def advice_payload_for(prompt)
        { model: model, temperature: 0.2, max_tokens: 120,
          messages: [{ role: "user", content: prompt }] }
      end

      def extract(body) = body.dig("choices", 0, "message", "content")

      Registry.register("llamacpp", self)
    end
  end
end
