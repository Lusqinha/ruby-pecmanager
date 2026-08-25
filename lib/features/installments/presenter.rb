# frozen_string_literal: true

module Features
  module Installments
    class Presenter
      def call(result)
        case result.status
        when :recorded then recorded(result)
        when :listed then listed(result)
        when :cancelled then cancelled(result)
        when :toggled then toggled(result)
        when :missing then Interface::ViewMessage.text("Parcelamento não encontrado.")
        else Interface::ViewMessage.text("Não reconheci o parcelamento. Exemplo: `1200 em 12x notebook`.")
        end
      end

      private

      def recorded(result)
        plan = result.plan
        Interface::ViewMessage.text(
          "✅ #{plan.description} · #{plan.count}x de #{Interface::Brl.format(plan.amount_for(1))} " \
          "· #{result.category ? result.category.name : 'sem categoria'}\n" \
          "Total #{Interface::Brl.format(plan.total)} · de #{month(plan.first_month)} a #{month(plan.last_month)}"
        )
      end

      def listed(result)
        return Interface::ViewMessage.text("Nenhum parcelamento em aberto.") if result.plans.empty?

        total = result.plans.reduce(Domain::Money.zero) { |sum, plan| sum + plan.due_in(result.month) }
        lines = result.plans.map { |plan| plan_line(plan, result.month) }
        lines += ["", "Comprometido este mês: *#{Interface::Brl.format(total)}*"]

        Interface::ViewMessage.new(text: lines.join("\n"), keyboard: keyboard(result))
      end

      def keyboard(result)
        result.plans.map { |plan| [["Encerrar #{plan.description}", "plan:cancel:#{plan.id}"]] } + [[toggle(result)]]
      end

      # O rótulo mostra o estado atual e o dado leva pro oposto.
      def toggle(result)
        return ["Contar no budget: sim", "plan:budget:off"] if result.in_budget

        ["Contar no budget: não", "plan:budget:on"]
      end

      def toggled(result)
        text = if result.in_budget
                 "As parcelas passam a consumir o budget das categorias."
               else
                 "As parcelas saem do budget e passam a aparecer apenas no bloco de parcelas."
               end
        Interface::ViewMessage.new(text: text, keyboard: keyboard(result))
      end

      def plan_line(plan, month)
        origin = plan.origin ? " · #{plan.origin}" : ""
        "· *#{plan.description}* #{plan.label_in(month)} · " \
          "#{Interface::Brl.format(plan.due_in(month))}#{origin} · até #{month(plan.last_month)}"
      end

      def cancelled(result)
        Interface::ViewMessage.text(
          "Parcelamento encerrado: #{result.plan.description}. #{result.cancelled_count} parcela(s) futura(s) " \
          "removida(s). A deste mês permanece."
        )
      end

      def month(date) = date.strftime("%m/%Y")
    end
  end
end
