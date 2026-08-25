# frozen_string_literal: true

require_relative "../../test_helper"
require_relative "../../support/slice_case"

class SavingsFlowTest < SliceCase
  def seed_boxes
    @factory.seed_user
    @factory.goals.replace_all(3, [
                                 Domain::Goal.new(name: "Viagem", target: Domain::Money.new(300_000)),
                                 Domain::Goal.new(name: "PC", target: Domain::Money.new(800_000))
                               ])
  end

  def box(name) = @factory.goals.for_user(3).find { |item| item.name == name }

  def test_deposits_land_in_one_box_only
    seed_boxes

    reply = send_text("/caixinha viagem 500")

    assert_equal 50_000, box("Viagem").saved.cents
    assert_equal 0, box("PC").saved.cents
    assert_includes reply.text, "Viagem"
    assert_includes reply.text, "R$ 500,00"
  end

  def test_a_negative_value_takes_money_out
    seed_boxes
    send_text("/caixinha viagem 500")

    send_text("/caixinha viagem -200")

    assert_equal 30_000, box("Viagem").saved.cents
  end

  def test_a_box_never_goes_negative
    seed_boxes

    reply = send_text("/caixinha viagem -100")

    assert_equal 0, box("Viagem").saved.cents
    assert_includes reply.text, "R$ 0,00"
  end

  def test_lists_every_box_with_its_own_balance
    seed_boxes
    send_text("/caixinha viagem 500")

    reply = send_text("/caixinhas")

    assert_includes reply.text, "Viagem"
    assert_includes reply.text, "R$ 500,00"
    assert_includes reply.text, "PC"
    assert_includes reply.text, "R$ 3.000,00"
  end

  def test_an_unknown_box_lists_the_available_ones
    seed_boxes

    reply = send_text("/caixinha ferias 100")

    assert_includes reply.text, "Viagem"
    assert_includes reply.text, "PC"
  end

  def test_asks_for_the_value_when_it_is_missing
    seed_boxes

    assert_includes send_text("/caixinha viagem").text, "valor"
  end

  def test_metas_still_works_as_an_alias
    seed_boxes

    assert_includes send_text("/metas").text, "Viagem"
  end
  def test_the_box_chart_shows_progress_and_the_forecast
    seed_boxes
    @factory.goals.replace_all(3, [
                                 Domain::Goal.new(name: "Reserva", target: Domain::Money.new(1_000_000),
                                                  deadline: Date.new(2027, 12, 1)),
                                 Domain::Goal.new(name: "Viagem", target: Domain::Money.new(300_000))
                               ])
    send_text("/caixinha reserva 1500")

    reply = tap_button("chart:boxes")

    assert reply.photo?
    assert_equal "\x89PNG\r\n\x1A\n".b, reply.photo[0, 8]
    assert_includes reply.text, "1. Reserva: R$ 1.500,00 de R$ 10.000,00"
    assert_includes reply.text, "/mês até 12/2027"
    assert_includes reply.text, "sem prazo"
  end

  def test_the_box_chart_needs_a_target
    @factory.seed_user
    @factory.goals.replace_all(3, [Domain::Goal.new(name: "Solta", target: Domain::Money.zero)])

    reply = tap_button("chart:boxes")

    refute reply.photo?
    assert_includes reply.text, "Nenhuma caixinha com valor"
  end
end
