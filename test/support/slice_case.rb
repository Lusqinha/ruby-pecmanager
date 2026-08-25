# frozen_string_literal: true

require_relative "stub_parser"

# Base for slice flow tests: real router, real slices, in-memory repositories.
class SliceCase < Minitest::Test
  def setup
    @clock = FrozenClock.new(today: TODAY, now: NOW)
    @factory = InMemory::Factory.new(clock: @clock, parser: StubParser.new)
    @router = @factory.router
  end

  def send_text(text, user_id: 3, name: nil) = @router.handle_text(user_id, text, name: name)
  def tap_button(data, user_id: 3) = @router.handle_callback(user_id, data)

  # Swaps in the real regex parser, standing in for "the LLM is unreachable".
  def with_regex_parser
    @factory.parser = Infrastructure::Parsing::RegexExpenseParser.new
  end

  def run_setup(user_id: 7, income_type: "clt")
    send_text("oi", user_id: user_id, name: "Lucas")
    tap_button(income_type, user_id: user_id)
    send_text("5000", user_id: user_id)
    send_text("pronto", user_id: user_id) # sem descontos
    tap_button("preset", user_id: user_id)
    Features::Setup::Presets.size.times { send_text("10%", user_id: user_id) }
    send_text("aluguel 1200 dia 10", user_id: user_id)
    send_text("pronto", user_id: user_id)
    send_text("netflix 39,90 dia 5", user_id: user_id)
    send_text("pronto", user_id: user_id)
    send_text("reserva 10000 até 12/2027", user_id: user_id)
    send_text("pronto", user_id: user_id)
    tap_button("confirmar", user_id: user_id)
    @factory.users.find(user_id)
  end
end
