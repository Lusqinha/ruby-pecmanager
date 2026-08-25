# frozen_string_literal: true

module Features
  module Account
    class Presenter
      LIMIT = 12

      def rollback(result)
        case result.status
        when :invalid then Interface::ViewMessage.text("Informe quantos minutos: `/reverter 30`.")
        when :applied then Interface::ViewMessage.text("Removido: #{summary(result)}.")
        else preview(result)
        end
      end

      def wipe(result)
        return Interface::ViewMessage.text("Dados apagados. Envie qualquer mensagem para iniciar uma nova configuração.") if result.status == :wiped

        Interface::ViewMessage.text("Nenhum dado foi apagado.")
      end

      def confirm_wipe
        Interface::ViewMessage.new(
          text: "Isso apaga *todos* os seus dados: gastos, parcelamentos, categorias, custos fixos, assinaturas e metas.\n" \
                "A ação não pode ser desfeita.",
          keyboard: [[["Apagar tudo", "wipe:yes"], ["Cancelar", "wipe:no"]]]
        )
      end

      private

      def preview(result)
        return Interface::ViewMessage.text("Nenhum lançamento nos últimos #{result.minutes} minutos.") if result.empty?

        lines = ["*Serão removidos* (últimos #{result.minutes} min):", ""]
        lines += result.expenses.first(LIMIT).map { |item| expense_line(item) }
        lines += result.plans.first(LIMIT).map { |item| plan_line(item) }
        lines << "_...e mais #{result.total - (LIMIT * 2)}._" if result.total > LIMIT * 2
        lines += ["", "#{summary(result)}."]

        Interface::ViewMessage.new(
          text: lines.join("\n"),
          keyboard: [[["Desfazer", "rollback:#{result.since.to_i}"], ["Cancelar", "wipe:no"]]]
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
