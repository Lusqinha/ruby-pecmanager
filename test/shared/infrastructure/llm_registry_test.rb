# frozen_string_literal: true

require_relative "../../test_helper"

# Proves the claim: a new provider is one class, with no edit to the container
# or to any existing adapter.
class LlmRegistryTest < Minitest::Test
  class FakeProviderParser < Infrastructure::Llm::HttpExpenseParser
    def initialize(base_url: "http://fake", model: "fake-1", **options)
      super(base_url: base_url, model: model, logger: nil, **options)
    end

    def endpoint = URI.join(base_url, "/answer")
    def payload_for(text, today, _categories = []) = { q: text, day: today.to_s }
    def extract(body) = body["data"]
  end

  def setup
    @previous_backend = ENV["LLM_BACKEND"]
    Infrastructure::Llm::Registry.register("fake", FakeProviderParser)
  end

  def teardown
    ENV["LLM_BACKEND"] = @previous_backend
    Infrastructure::Llm::Registry.adapters.delete("fake")
  end

  def container
    Config::Container.new(db: Infrastructure::Persistence::SequelStore::Database.connect(":memory:"))
  end

  def test_registered_adapter_is_selected_by_name
    ENV["LLM_BACKEND"] = "fake"

    assert_instance_of FakeProviderParser, container.llm_parser
  end

  def test_defaults_to_ollama
    ENV.delete("LLM_BACKEND")

    assert_instance_of Infrastructure::Llm::OllamaExpenseParser, container.llm_parser
  end

  def test_llamacpp_is_registered
    ENV["LLM_BACKEND"] = "llamacpp"

    assert_instance_of Infrastructure::Llm::LlamaExpenseParser, container.llm_parser
  end

  def test_unknown_backend_fails_loudly_and_lists_the_options
    ENV["LLM_BACKEND"] = "gpt42"

    error = assert_raises(Infrastructure::Llm::Registry::UnknownBackend) { container.llm_parser }

    assert_includes error.message, "ollama"
  end

  def test_base_class_turns_the_provider_answer_into_a_dto
    parser = FakeProviderParser.new
    inner = JSON.generate({ amount: "35,00", description: "mercado", category_hint: "mercado", date: "2026-08-24" })
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.instance_variable_set(:@body, JSON.generate({ data: inner }))
    parser.define_singleton_method(:post) { |_uri, _body| response }

    result = parser.parse("35 mercado", today: TODAY)

    assert_equal 3_500, result.amount.cents
    assert_equal "mercado", result.category_hint
    assert_equal "llm", result.source
  end

  def test_hooks_are_mandatory
    incomplete = Class.new(Infrastructure::Llm::HttpExpenseParser).new(base_url: "http://x", model: "y", logger: nil)

    assert_raises(NotImplementedError) { incomplete.endpoint }
  end
end
