# frozen_string_literal: true

require_relative "../../test_helper"

class OllamaExpenseParserTest < Minitest::Test
  # Replaces only the HTTP call, so payload building and response handling stay
  # under test.
  class StubbedOllama < Infrastructure::Llm::OllamaExpenseParser
    attr_reader :sent_payload

    def initialize(response_or_error, **options)
      @response_or_error = response_or_error
      super(base_url: "http://phone:11434", model: "qwen2.5:1.5b", logger: nil, **options)
    end

    private

    def post(_uri, body)
      @sent_payload = body
      raise @response_or_error if @response_or_error.is_a?(Exception)

      @response_or_error
    end
  end

  def http_ok(body)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, body)
    response
  end

  def answer(amount: "89,90", date: "2026-08-21")
    inner = JSON.generate({ amount: amount, description: "farmácia", category_hint: "saude", date: date })
    http_ok(JSON.generate({ response: inner, done: true }))
  end

  def test_parses_the_native_response_field
    result = StubbedOllama.new(answer).parse("89,90 farmácia sexta", today: TODAY)

    assert_equal 8_990, result.amount.cents
    assert_equal "saude", result.category_hint
    assert_equal Date.new(2026, 8, 21), result.spent_on
    assert_equal "llm", result.source
  end

  def test_sends_the_phone_tuned_options
    parser = StubbedOllama.new(answer)
    parser.parse("35 mercado", today: TODAY)
    options = parser.sent_payload[:options]

    assert_equal 512, options[:num_ctx]
    assert_equal 80, options[:num_predict]
    assert_equal 4, options[:num_thread]
    assert_equal 0, options[:temperature]
    refute parser.sent_payload[:stream]
  end

  def test_pins_the_model_in_ram_by_default
    parser = StubbedOllama.new(answer)
    parser.parse("35 mercado", today: TODAY)

    assert_equal(-1, parser.sent_payload[:keep_alive])
  end

  def test_keep_alive_accepts_a_duration_string
    parser = StubbedOllama.new(answer, keep_alive: "30m")
    parser.parse("35 mercado", today: TODAY)

    assert_equal "30m", parser.sent_payload[:keep_alive]
  end

  def test_options_can_be_overridden
    parser = StubbedOllama.new(answer, options: { num_ctx: 1024 })
    parser.parse("35 mercado", today: TODAY)

    assert_equal 1024, parser.sent_payload[:options][:num_ctx]
    assert_equal 4, parser.sent_payload[:options][:num_thread] # defaults survive
  end

  def test_constrains_decoding_with_a_json_schema
    parser = StubbedOllama.new(answer)
    parser.parse("35 mercado", today: TODAY)

    assert_equal "object", parser.sent_payload[:format][:type]
    assert_equal %w[amount description category_hint date], parser.sent_payload[:format][:required]
  end

  def test_prompt_stays_short_and_carries_today
    parser = StubbedOllama.new(answer)
    parser.parse("35 mercado", today: TODAY)

    assert_includes parser.sent_payload[:system], "2026-08-24"
    assert_operator parser.sent_payload[:system].length, :<, 200 # prompt processing is the phone's bottleneck
  end

  def test_invalid_json_returns_nil
    assert_nil StubbedOllama.new(http_ok(JSON.generate({ response: "não é json" }))).parse("35 mercado", today: TODAY)
  end

  def test_timeout_returns_nil
    assert_nil StubbedOllama.new(Net::ReadTimeout.new).parse("35 mercado", today: TODAY)
  end

  def test_connection_refused_returns_nil
    assert_nil StubbedOllama.new(Errno::ECONNREFUSED.new).parse("35 mercado", today: TODAY)
  end

  def test_zero_amount_returns_nil
    assert_nil StubbedOllama.new(answer(amount: "0")).parse("nada", today: TODAY)
  end

  def test_unparseable_date_falls_back_to_today
    assert_equal TODAY, StubbedOllama.new(answer(date: "amanhã")).parse("10 x", today: TODAY).spent_on
  end

  def test_warmup_reports_failure_instead_of_raising
    refute StubbedOllama.new(Errno::ECONNREFUSED.new).warmup
    assert StubbedOllama.new(answer).warmup
  end
end
