# frozen_string_literal: true

require_relative "../../test_helper"
require "telegram/bot"
require_relative "../../../lib/shared/infrastructure/telegram/bot_runner"

class BotRunnerTest < Minitest::Test
  # Só a busca do arquivo é real; o HTTP é substituído.
  class StubbedRunner < Infrastructure::Telegram::BotRunner
    attr_reader :fetched

    def initialize(body: %({"lancamentos":[]}), **options)
      @body = body
      super(**options)
    end

    def fetch(uri)
      @fetched = uri.to_s
      response = Net::HTTPOK.new("1.1", "200", "OK")
      response.instance_variable_set(:@read, true)
      response.instance_variable_set(:@body, @body)
      response
    end
  end

  # O que a gem devolve hoje: o próprio tipo File, sem invólucro.
  FakeApi = Struct.new(:answer) do
    def get_file(file_id:) = answer
  end
  FakeBot = Struct.new(:api)

  Document = Struct.new(:file_name, :file_size, :file_id, keyword_init: true)

  def download(answer, document)
    runner = StubbedRunner.new(controller: nil, token: "123:ABC", allowed_user_ids: [3], logger: nil)
    runner.send(:document_text, FakeBot.new(FakeApi.new(answer)), document)
  end

  def json_document = Document.new(file_name: "fatura.json", file_size: 200, file_id: "abc")

  def test_reads_the_file_path_straight_off_the_telegram_type
    answer = Telegram::Bot::Types::File.new(file_id: "abc", file_unique_id: "u", file_path: "documents/f.json")

    assert_equal %({"lancamentos":[]}), download(answer, json_document)
  end

  def test_still_understands_the_old_hash_shape
    assert_equal %({"lancamentos":[]}), download({ "result" => { "file_path" => "documents/f.json" } }, json_document)
  end

  def test_ignores_anything_that_is_not_json
    answer = Telegram::Bot::Types::File.new(file_id: "abc", file_unique_id: "u", file_path: "documents/f.pdf")

    assert_nil download(answer, Document.new(file_name: "fatura.pdf", file_size: 200, file_id: "abc"))
  end

  def test_refuses_a_file_over_the_size_limit
    answer = Telegram::Bot::Types::File.new(file_id: "abc", file_unique_id: "u", file_path: "documents/f.json")
    big = Document.new(file_name: "fatura.json", file_size: 5_000_000, file_id: "abc")

    assert_nil download(answer, big)
  end

  def test_a_broken_answer_is_swallowed_instead_of_killing_the_loop
    assert_nil download(Object.new, json_document)
  end

  # Registra o que a gem receberia: o arquivo sai com o nome do ViewMessage.
  SendingApi = Struct.new(:sent) do
    def send_document(**payload) = sent << payload
  end

  def test_a_view_message_with_a_document_is_sent_as_a_file
    api = SendingApi.new([])
    runner = StubbedRunner.new(controller: nil, token: "123:ABC", allowed_user_ids: [3], logger: nil)
    reply = Interface::ViewMessage.file("# oi", filename: "pecman-2026-08-25.md", caption: "Exportação")

    runner.send(:send_reply, FakeBot.new(api), 9, reply)
    payload = api.sent.first

    assert_equal 9, payload[:chat_id]
    assert_equal "Exportação", payload[:caption]
    assert_equal "pecman-2026-08-25.md", payload[:document].original_filename
  end
end
