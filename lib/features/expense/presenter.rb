# frozen_string_literal: true

module Features
  module Expense
    class Presenter
      MISSING = "Esse lançamento não existe mais."

      def call(result)
        case result.status
        when :recorded then recorded(result)
        when :needs_category then needs_category(result)
        when :unparseable then Interface::ViewMessage.text("Não entendi. Manda algo como `35 mercado` ou `12,50 uber ontem`.")
        else Interface::ViewMessage.text(MISSING)
        end
      end

      def undo(result)
        case result.status
        when :undone then Interface::ViewMessage.text("Desfeito: #{Interface::Brl.format(result.expense.amount)} #{result.expense.description}")
        when :too_old then Interface::ViewMessage.text("Passou da janela de 5 min pra desfazer. Use /mes pra revisar.")
        else Interface::ViewMessage.text("Nada pra desfazer.")
        end
      end

      private

      def recorded(result)
        expense = result.expense
        tail =
          if result.limit.zero?
            "#{Interface::Brl.format(result.spent_in_month)} no mês (sem limite)"
          else
            "restam #{Interface::Brl.format(result.limit - result.spent_in_month)} de #{Interface::Brl.format(result.limit)}"
          end

        Interface::ViewMessage.new(
          text: "✅ #{Interface::Brl.format(expense.amount)} · #{result.category.name} · #{expense.spent_on.strftime('%d/%m')}\n#{tail}",
          keyboard: [[["Trocar categoria", "chg:#{expense.id}"], ["Desfazer", "undo:#{expense.id}"]]]
        )
      end

      def needs_category(result)
        expense = result.expense
        Interface::ViewMessage.new(
          text: "#{Interface::Brl.format(expense.amount)} · #{expense.description} · #{expense.spent_on.strftime('%d/%m')}\nEm qual categoria?",
          keyboard: result.categories.map { |category| [category.name, "cat:#{expense.id}:#{category.id}"] }.each_slice(2).to_a
        )
      end
    end
  end
end
