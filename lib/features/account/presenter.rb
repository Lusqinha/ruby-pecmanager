# frozen_string_literal: true

module Features
  module Account
    class Presenter
      LIMIT = 12

      def rollback(result)
        case result.status
        when :invalid then Interface::ViewMessage.text("Diz quantos minutos: `/reverter 30`.")
        when :applied then Interface::ViewMessage.text("Revertido: #{summary(result)} saíram.")
        else preview(result)
        end
      end

      def wipe(result)
        return Interface::ViewMessage.text("Tudo apagado. Manda qualquer coisa pra começar de novo.") if result.status == :wiped

        Interface::ViewMessage.text("Nada apagado.")
      end

      def confirm_wipe
        Interface::ViewMessage.new(
          text: "Isso apaga *tudo*: gastos, parcelamentos, categorias, custos fixos, assinaturas e metas.\n" \
                "Não dá pra desfazer depois.",
          keyboard: [[["Apagar tudo", "wipe:yes"], ["Deixa quieto", "wipe:no"]]]
        )
      end

      private

      def preview(result)
        return Interface::ViewMessage.text("Nada lançado nos últimos #{result.minutes} min.") if result.empty?

        lines = ["*Vou desfazer isto* (últimos #{result.minutes} min):", ""]
        lines += result.expenses.first(LIMIT).map { |item| expense_line(item) }
        lines += result.plans.first(LIMIT).map { |item| plan_line(item) }
        lines << "_...e mais #{result.total - (LIMIT * 2)}._" if result.total > LIMIT * 2
        lines += ["", "#{summary(result)}."]

        Interface::ViewMessage.new(
          text: lines.join("\n"),
          keyboard: [[["Desfazer", "rollback:#{result.since.to_i}"], ["Deixa quieto", "wipe:no"]]]
        )
      end

      def expense_line(item)
        "· #{Interface::Brl.format(item.amount)} #{item.description} (#{item.spent_on.strftime('%d/%m')})"
      end

      def plan_line(item)
        "· #{item.description} #{item.count}x de #{Interface::Brl.format(item.amount_for(1))}"
      end

      def summary(result)
        parts = []
        parts << "#{result.expenses.to_a.size} gasto(s)" if result.expenses.to_a.any?
        parts << "#{result.plans.to_a.size} parcelamento(s)" if result.plans.to_a.any?
        parts.join(" e ")
      end
    end
  end
end
