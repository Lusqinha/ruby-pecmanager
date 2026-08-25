# frozen_string_literal: true

module Features
  module Budgets
    class Presenter
      HINT = "Mudar: `/budget mercado 500` · `/budget lazer 10%` · `/budget extras livre`"

      def call(result)
        case result.status
        when :listed then Interface::ViewMessage.text(listed(result).join("\n"))
        when :updated then Interface::ViewMessage.text(updated(result).join("\n"))
        when :no_plan then Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.")
        when :unknown_category
          Interface::ViewMessage.text("Categoria não encontrada. Disponíveis: #{result.names.join(', ')}.")
        when :invalid_limit
          Interface::ViewMessage.text("Não entendi o valor. #{HINT}")
        end
      end

      private

      def updated(result)
        ["*#{result.category_name}*: #{money(result.previous)} → #{money(current(result))}", ""] + listed(result)
      end

      def current(result)
        result.lines.find { |line| line.category_name == result.category_name }&.amount || Domain::Money.zero
      end

      def listed(result)
        summary = result.summary
        lines = ["*Budgets* — #{result.month.strftime('%m/%Y')}",
                 "Para dividir entre as categorias: *#{money(summary.available)}*/mês",
                 "_líquido #{money(summary.salary)} − fixos #{money(summary.fixed_costs)} " \
                 "− caixinhas #{money(summary.goals)}#{subscriptions(summary)}_", ""]
        lines += result.lines.map { |line| budget_line(line) }
        lines += ["", totals(summary), "", HINT]
        lines
      end

      # Assinatura sem categoria própria some do teto e sai direto da renda: o
      # rodapé precisa dizer qual dos dois é o caso.
      def subscriptions(summary)
        return "" unless summary.subscriptions.positive?
        return " (assinaturas dentro dos budgets)" if summary.subscriptions_in_budget?

        " − assinaturas #{money(summary.subscriptions)}"
      end

      def budget_line(line)
        return "· *#{line.category_name}*: sem limite" if line.limit.none?
        return "· *#{line.category_name}*: #{line.limit.value}% = #{money(line.amount)}" if line.limit.percent?

        "· *#{line.category_name}*: #{money(line.amount)}"
      end

      def totals(summary)
        return "Somam #{money(summary.committed)} · ⚠️ *#{money(summary.over)} acima do que sobra*" if summary.over?

        "Somam #{money(summary.committed)} · livre #{money(summary.free)}"
      end

      def money(value) = Interface::Brl.format(value)
    end
  end
end
