# frozen_string_literal: true

module Features
  module Installments
    class Presenter
      def call(result)
        case result.status
        when :recorded then recorded(result)
        when :listed then listed(result)
        when :cancelled then cancelled(result)
        when :missing then Interface::ViewMessage.text("Não achei esse parcelamento.")
        else Interface::ViewMessage.text("Não entendi o parcelamento. Tenta `1200 em 12x notebook`.")
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
        return Interface::ViewMessage.text("Nenhum parcelamento ativo.") if result.plans.empty?

        total = result.plans.reduce(Domain::Money.zero) { |sum, plan| sum + plan.due_in(result.month) }
        lines = result.plans.map { |plan| plan_line(plan, result.month) }
        lines += ["", "Comprometido este mês: *#{Interface::Brl.format(total)}*"]

        Interface::ViewMessage.new(
          text: lines.join("\n"),
          keyboard: result.plans.map { |plan| [["Encerrar #{plan.description}", "plan:cancel:#{plan.id}"]] }
        )
      end

      def plan_line(plan, month)
        origin = plan.origin ? " · #{plan.origin}" : ""
        "· *#{plan.description}* #{plan.label_in(month)} · " \
          "#{Interface::Brl.format(plan.due_in(month))}#{origin} · até #{month(plan.last_month)}"
      end

      def cancelled(result)
        Interface::ViewMessage.text(
          "Encerrado: #{result.plan.description}. #{result.cancelled_count} parcela(s) futura(s) " \
          "saíram da conta; a deste mês continua."
        )
      end

      def month(date) = date.strftime("%m/%Y")
    end
  end
end
