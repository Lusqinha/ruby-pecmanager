# frozen_string_literal: true

module Infrastructure
  module Llm
    # Uses the native API, not the OpenAI-compatible one: that endpoint ignores
    # `options` and `keep_alive`, the knobs that make a small model usable on a
    # CPU-only host.
    class OllamaExpenseParser < HttpExpenseParser
      # Ollama constrains decoding to this schema, so the model cannot ramble
      # outside the object.
      SCHEMA = {
        type: "object",
        properties: FIELDS.to_h { |field| [field, { type: "string" }] },
        required: FIELDS
      }.freeze

      DEFAULTS = {
        # Prompt and answer are tiny; a smaller window cuts processing time.
        num_ctx: 512,
        # A full answer is ~40 tokens; the cap stops the model from padding.
        num_predict: 80,
        # Matches the host's performance cores: more threads spill onto the
        # efficiency cores and get slower, not faster.
        num_thread: 4,
        temperature: 0
      }.freeze

      def initialize(base_url: ENV.fetch("LLAMA_URL", "http://localhost:11434"),
                     model: ENV.fetch("LLAMA_MODEL", "qwen2.5:1.5b"),
                     timeout: Integer(ENV.fetch("LLAMA_TIMEOUT", "8")),
                     # -1 pins the model in RAM: without it, an idle gap means
                     # reloading the whole model before answering.
                     keep_alive: ENV.fetch("LLM_KEEP_ALIVE", "-1"),
                     options: {},
                     logger: $stderr)
        super(base_url: base_url, model: model, timeout: timeout, logger: logger)
        @keep_alive = numeric_keep_alive(keep_alive)
        @options = DEFAULTS.merge(env_options).merge(options)
      end

      def endpoint = URI.join(base_url, "/api/generate")

      def payload_for(text, today, categories = [])
        { model: model, system: system_prompt(today, categories), prompt: text.to_s, stream: false,
          format: SCHEMA, keep_alive: @keep_alive, options: @options }
      end

      def extract(body) = body["response"]

      def warmup
        post(endpoint, { model: model, prompt: "", stream: false, keep_alive: @keep_alive })
        true
      rescue StandardError => e
        logger&.puts("[llm] warmup falhou: #{e.class}: #{e.message}")
        false
      end

      private

      def env_options
        { num_ctx: ENV["LLM_NUM_CTX"]&.to_i, num_predict: ENV["LLM_NUM_PREDICT"]&.to_i,
          num_thread: ENV["LLM_NUM_THREAD"]&.to_i }.compact
      end

      def numeric_keep_alive(value)
        Integer(value.to_s)
      rescue ArgumentError, TypeError
        value # durations like "30m" stay as given
      end

      Registry.register("ollama", self)
    end
  end
end
