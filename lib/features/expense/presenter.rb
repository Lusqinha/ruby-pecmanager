# frozen_string_literal: true

module Features
  module Expense
    class Presenter
      MISSING = "Esse lançamento não existe mais."

      def call(result)
        case result.status
        when :recorded then recorded(result)
        when :needs_category then needs_category(result)
        when :unparseable then Interface::ViewMessage.text("Não identifiquei um valor. Envie algo como `35 mercado` ou `12,50 uber ontem`.")
        else Interface::ViewMessage.text(MISSING)
        end
      end

      def undo(result)
        case result.status
        when :undone then Interface::ViewMessage.text("Desfeito: #{Interface::Brl.format(result.expense.amount)} #{result.expense.description}")
        when :too_old then Interface::ViewMessage.text("O prazo de 5 minutos para desfazer já passou. Use /mes para revisar.")
        else Interface::ViewMessage.text("Não há lançamento recente para desfazer.")
        end
      end

      private

      def recorded(result)
        expense = result.expense
        lines = ["✅ #{Interface::Brl.format(expense.amount)} · #{result.category.name} · #{expense.spent_on.strftime('%d/%m')}",
                 status(result)]
        lines += rebalance(result)

        Interface::ViewMessage.new(
          text: lines.join("\n"),
          keyboard: [[["Trocar categoria", "chg:#{expense.id}"], ["Desfazer", "undo:#{expense.id}"]]]
        )
      end

      def status(result)
        return "#{Interface::Brl.format(result.spent_in_month)} no mês (sem limite)" if result.limit.zero?
        return "restam #{Interface::Brl.format(result.limit - result.spent_in_month)} de #{Interface::Brl.format(result.limit)}" if result.spent_in_month <= result.limit

        "⚠️ estourou #{Interface::Brl.format(result.spent_in_month - result.limit)} do teto de #{Interface::Brl.format(result.limit)}"
      end

      # Estourou: mostrar de onde tirar a cota é mais útil do que só avisar. A
      # soma dos tetos continua a mesma, então o mês não estoura junto.
      def rebalance(result)
        return [] if result.moves.to_a.empty?

        total = result.moves.reduce(Domain::Money.zero) { |sum, move| sum + move.amount }
        ["", "*Remanejo sugerido para este mês* (#{Interface::Brl.format(total)} → #{result.category.name}):"] +
          result.moves.map { |move| move_line(move) } +
          ["_A soma dos tetos não muda._"]
      end

      def move_line(move)
        "· *#{move.from}*: #{Interface::Brl.format(move.limit)} → #{Interface::Brl.format(move.limit - move.amount)} " \
          "(gastou #{Interface::Brl.format(move.spent)})"
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
