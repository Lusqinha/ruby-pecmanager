# frozen_string_literal: true

require_relative "../../test_helper"

class LlamaExpenseParserTest < Minitest::Test
  # Replaces only the HTTP call, so payload building and response handling are
  # the code under test.
  class StubbedLlama < Infrastructure::Llm::LlamaExpenseParser
    attr_reader :sent_payload

    def initialize(response_or_error)
      @response_or_error = response_or_error
      super(logger: nil)
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

  def completion(content) = http_ok(JSON.generate({ choices: [{ message: { content: content } }] }))

  def payload(amount: "89,90", date: "2026-08-21")
    JSON.generate({ amount: amount, description: "farmácia", category_hint: "saude", date: date })
  end

  def test_parses_a_structured_answer
    result = StubbedLlama.new(completion(payload)).parse("gastei 89,90 na farmácia sexta", today: TODAY)

    assert_equal 8_990, result.amount.cents
    assert_equal "saude", result.category_hint
    assert_equal Date.new(2026, 8, 21), result.spent_on
    assert_equal "llm", result.source
  end

  def test_lists_the_user_categories_in_the_prompt
    parser = StubbedLlama.new(completion(payload))
    parser.parse("50 xis salada", today: TODAY, categories: ["Alimentação", "Transporte"])

    assert_includes parser.sent_payload[:messages].first[:content], "Alimentação; Transporte"
  end

  def test_asks_for_a_json_schema_at_temperature_zero
    parser = StubbedLlama.new(completion(payload))
    parser.parse("35 mercado", today: TODAY)

    assert_equal 0, parser.sent_payload[:temperature]
    assert_equal "json_schema", parser.sent_payload[:response_format][:type]
    assert_includes parser.sent_payload[:messages].first[:content], "2026-08-24"
  end

  def test_invalid_json_returns_nil
    assert_nil StubbedLlama.new(completion("não é json")).parse("35 mercado", today: TODAY)
  end

  def test_timeout_returns_nil
    assert_nil StubbedLlama.new(Net::OpenTimeout.new).parse("35 mercado", today: TODAY)
  end

  def test_http_error_returns_nil
    assert_nil StubbedLlama.new(Net::HTTPServerError.new("1.1", "500", "Boom")).parse("35 mercado", today: TODAY)
  end

  def test_zero_amount_returns_nil
    assert_nil StubbedLlama.new(completion(payload(amount: "0"))).parse("nada", today: TODAY)
  end

  def test_unparseable_date_falls_back_to_today
    result = StubbedLlama.new(completion(payload(date: "amanhã"))).parse("10 x", today: TODAY)

    assert_equal TODAY, result.spent_on
  end
end
