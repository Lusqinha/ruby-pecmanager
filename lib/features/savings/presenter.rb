# frozen_string_literal: true

module Features
  module Savings
    class Presenter
      def call(result)
        case result.status
        when :deposited then deposited(result)
        when :listed then listed(result)
        when :no_boxes then Interface::ViewMessage.text("Nenhuma caixinha cadastrada. Use /setup para criar.")
        when :missing_amount then Interface::ViewMessage.text("Informe o valor: `/caixinha viagem 200`.")
        when :unknown_box then Interface::ViewMessage.text("Caixinha não encontrada. Disponíveis: #{result.names.join(', ')}.")
        end
      end

      private

      def deposited(result)
        box = result.box
        verb, preposition = result.amount.negative? ? %w[Retirado de] : %w[Guardado em]
        Interface::ViewMessage.text(
          "#{verb} #{Interface::Brl.format(abs(result.amount))} #{preposition} *#{box.name}*.\n" \
          "Saldo: #{Interface::Brl.format(box.saved)}#{target(box)}"
        )
      end

      def target(box)
        return "" if box.target.zero?

        missing = [box.target - box.saved, Domain::Money.zero].max
        return " de #{Interface::Brl.format(box.target)} — completa." if missing.zero?

        " de #{Interface::Brl.format(box.target)} · faltam #{Interface::Brl.format(missing)}"
      end

      def listed(result)
        return Interface::ViewMessage.text("Nenhuma caixinha cadastrada. Use /setup para criar.") if result.boxes.empty?

        total = result.boxes.reduce(Domain::Money.zero) { |sum, box| sum + box.saved }
        lines = result.boxes.map { |box| box_line(box) }
        lines += ["", "Total guardado: *#{Interface::Brl.format(total)}*"]

        Interface::ViewMessage.text(lines.join("\n"))
      end

      def box_line(box)
        bar, pct = box.target.zero? ? ["", nil] : Interface::Brl.bar(box.saved, box.target)
        head = "· *#{box.name}*: #{Interface::Brl.format(box.saved)}"
        return head if box.target.zero?

        "#{head} de #{Interface::Brl.format(box.target)} #{bar} (#{pct}%)#{pace(box)}"
      end

      def pace(box)
        return " — completa" if box.complete?
        return "" unless box.monthly.positive?

        "\n  #{Interface::Brl.format(box.monthly)}/mês até #{box.deadline.strftime('%m/%Y')}"
      end

      def abs(money) = money.negative? ? Domain::Money.zero - money : money
    end
  end
end
