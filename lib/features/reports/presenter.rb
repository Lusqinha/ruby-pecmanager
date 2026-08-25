# frozen_string_literal: true

module Features
  module Reports
    class Presenter
      def daily(report)
        return Interface::ViewMessage.text("Nenhum lançamento hoje.") if report.entries.empty?

        lines = ["*Hoje (#{report.date.strftime('%d/%m')})* — #{Interface::Brl.format(report.total)}", ""]
        lines += report.entries.map do |entry|
          "· #{Interface::Brl.format(entry.amount)} #{entry.description} (#{entry.category_name || 'sem categoria'})"
        end
        Interface::ViewMessage.text(lines.join("\n"))
      end

      def monthly(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        summary = report.summary
        lines = ["*#{report.month.strftime('%m/%Y')}* — gasto #{Interface::Brl.format(report.total)} de #{Interface::Brl.format(summary.committed)} em budgets", ""]
        lines += report.lines.map { |line| category_line(line.category_name, line.spent, line.limit) }
        lines << "· sem categoria: #{Interface::Brl.format(report.uncategorized)}" if report.uncategorized.positive?
        lines += installment_block(report)
        lines += ["", "Fixos #{Interface::Brl.format(summary.fixed_costs)} · assinaturas #{Interface::Brl.format(summary.subscriptions)} · caixinhas #{Interface::Brl.format(summary.goals)}",
                  "Sobra do mês: *#{Interface::Brl.format(summary.available - report.total - report.installments_total)}*"]
        Interface::ViewMessage.text(lines.join("\n"))
      end

      def category(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        unless report.found?
          return Interface::ViewMessage.text("Categoria não encontrada. Disponíveis: #{report.available_names.join(', ')}")
        end

        lines = ["*#{report.category_name}* — #{report.month.strftime('%m/%Y')}",
                 category_line(report.category_name, report.spent, report.limit), ""]
        lines += report.entries.map { |entry| "· #{entry.date.strftime('%d/%m')} #{Interface::Brl.format(entry.amount)} #{entry.description}" }
        lines << "_Sem lançamentos neste mês._" if report.entries.empty?
        Interface::ViewMessage.text(lines.join("\n"))
      end

      def projection(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        lines = ["*Projeção* — líquido #{Interface::Brl.format(report.net_income)}/mês", ""]
        lines += report.lines.map { |line| projection_line(line) }
        lines += ["", *report.goals.map { |goal| goal_forecast(goal) }] unless report.goals.empty?

        Interface::ViewMessage.text(lines.join("\n"))
      end

      private

      def installment_block(report)
        return [] if report.installment_lines.to_a.empty?

        ["", "*Parcelas* — #{Interface::Brl.format(report.installments_total)}"] +
          report.installment_lines.map do |line|
            origin = line.origin ? " · #{line.origin}" : ""
            "· #{line.description} #{line.label} · #{Interface::Brl.format(line.amount)}#{origin}"
          end
      end

      def category_line(name, spent, limit)
        return "· #{name}: #{Interface::Brl.format(spent)} (sem limite)" if limit.zero?

        bar, pct = Interface::Brl.bar(spent, limit)
        "· #{name}: #{bar} #{Interface::Brl.format(spent)}/#{Interface::Brl.format(limit)} (#{pct}%)"
      end

      def projection_line(line)
        "#{line.month.strftime('%m/%y')} · parcelas #{Interface::Brl.format(line.installments)} · " \
          "sobra #{Interface::Brl.format(line.leftover)} · acum #{Interface::Brl.format(line.accumulated)}"
      end

      def goal_forecast(goal)
        return "· #{goal.name}: fora do horizonte da projeção" unless goal.covered_on

        "✅ #{goal.name} (#{Interface::Brl.format(goal.target)}) em #{goal.covered_on.strftime('%m/%Y')}"
      end

      def goal_line(item)
        pace = item.monthly.positive? ? " · #{Interface::Brl.format(item.monthly)}/mês até #{item.deadline.strftime('%m/%Y')}" : ""
        "· *#{item.name}*: #{Interface::Brl.format(item.saved)} de #{Interface::Brl.format(item.target)}#{pace}"
      end
    end
  end
end
