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
        lines = [monthly_header(report), ""]
        lines += report.lines.map { |line| category_line(line.category_name, line.spent, line.limit) }
        lines << "· sem categoria: #{Interface::Brl.format(report.uncategorized)}" if report.uncategorized.positive?
        lines += installment_block(report)
        lines += ["", "Fixos #{Interface::Brl.format(summary.fixed_costs)} · #{subscriptions_note(summary)} · caixinhas #{Interface::Brl.format(summary.goals)}",
                  "Sobra do mês: *#{Interface::Brl.format(summary.available - report.total - report.installments_total)}*"]
        lines += allocation_block(report)
        lines += moves_block(report)

        Interface::ViewMessage.new(text: lines.join("\n"), keyboard: month_nav(report))
      end

      def unknown_month
        Interface::ViewMessage.text("Não entendi o mês. Use `/mes out/26`, `/mes 10/2026` ou `/mes outubro`.")
      end

      private

      def monthly_header(report)
        head = "*#{report.month.strftime('%m/%Y')}*"
        head += " — previsão" unless report.current?
        "#{head} — #{Interface::Brl.format(report.total)} de #{Interface::Brl.format(report.summary.committed)} em budgets"
      end

      # Andar mês a mês sem digitar comando: o mês futuro mostra os tetos e as
      # parcelas que já estão marcadas para ele.
      def month_nav(report)
        [[["◀ #{report.previous_month.strftime('%m/%y')}", "month:#{report.previous_month.strftime('%Y-%m')}"],
          ["#{report.next_month.strftime('%m/%y')} ▶", "month:#{report.next_month.strftime('%Y-%m')}"]]]
      end

      # A sobra sai dos tetos cheios, não do gasto até agora: é o piso que o
      # mês garante mesmo se todas as categorias forem até o limite.
      def allocation_block(report)
        return [] if report.allocation.to_a.empty?

        ["", "*Guardar em #{report.month.strftime('%m/%Y')}* — #{Interface::Brl.format(report.leftover)} com os tetos cheios"] +
          report.allocation.map { |share| share_line(share) }
      end

      def share_line(share)
        goal = share.goal
        tail = share.priority? && goal.deadline ? " — prioridade, prazo #{goal.deadline.strftime('%m/%Y')}" : ""
        "· *#{goal.name}*: #{Interface::Brl.format(share.amount)}#{tail}"
      end

      def moves_block(report)
        return [] if report.moves.to_a.empty?

        hole = report.moves.reduce(Domain::Money.zero) { |sum, move| sum + move.amount }
        ["", "*Remanejo sugerido* — faltam #{Interface::Brl.format(hole)} para o ritmo das caixinhas"] +
          report.moves.map { |move| move_line(move) } +
          ["_A soma dos tetos não muda; vale só para este mês._"]
      end

      def move_line(move)
        "· *#{move.from}*: #{Interface::Brl.format(move.limit)} → #{Interface::Brl.format(move.limit - move.amount)} " \
          "(gastou #{Interface::Brl.format(move.spent)})#{move.to ? " → #{move.to}" : ''}"
      end

      public

      # O botão das caixinhas é atendido pelo slice de caixinhas: aqui só o
      # rótulo e o dado do callback.
      def weekly(report, advice = nil)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        header = "*Semana de #{report.from.strftime('%d/%m')} a #{report.to.strftime('%d/%m')}*"
        lines = [header, week_total(report), ""]
        lines << "Restam *#{report.days_left} dias* no mês:"
        lines += report.lines.map { |line| weekly_line(line) }
        lines += ["", "*Parecer*", advice] if advice

        Interface::ViewMessage.text(lines.join("\n"))
      end

      private

      def week_total(report)
        return "Nenhum gasto lançado nesta semana." if report.spent.zero?

        "Gasto na semana: #{Interface::Brl.format(report.spent)}"
      end

      def weekly_line(line)
        week = line.week.positive? ? " (#{Interface::Brl.format(line.week)} nesta semana)" : ""
        return "· *#{line.category_name}*: budget estourado#{week}" if line.over?

        "· *#{line.category_name}*: restam #{Interface::Brl.format(line.left)} " \
          "— #{Interface::Brl.format(line.per_day)}/dia#{week}"
      end

      public

      def chart_menu
        Interface::ViewMessage.new(
          text: "Qual gráfico?",
          keyboard: [[["Categorias", "chart:categories"]],
                     [["Gastos mês a mês", "chart:months"]],
                     [["Caixinhas", "chart:boxes"]],
                     [["Acumulado da projeção", "chart:accumulated"]]]
        )
      end

      def chart(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        rows = report.lines.reject { |line| line.limit.zero? }
        return Interface::ViewMessage.text("Nenhuma categoria com limite definido. Use /setup.") if rows.empty?

        Interface::ViewMessage.image(
          Interface::BarChart.render(rows.map { |line| { label: line.category_name, value: remaining(line), limit: line.limit } },
                                     palette: :remaining),
          caption: chart_caption(report, rows)
        )
      end

      # O gráfico mostra o que ainda dá pra gastar, não o que já saiu.
      def remaining(line) = [line.limit - line.spent, Domain::Money.zero].max

      def chart_caption(report, rows)
        left = rows.reduce(Domain::Money.zero) { |sum, line| sum + remaining(line) }
        lines = ["*#{report.month.strftime('%m/%Y')}* — resta #{Interface::Brl.format(left)} nos budgets", ""]
        lines += rows.each_with_index.map { |line, index| chart_legend(line, index) }
        lines << "" << "Parcelas: #{Interface::Brl.format(report.installments_total)}" if report.installments_total.positive?
        lines.join("\n")
      end

      def chart_legend(line, index)
        left = remaining(line)
        status = left.zero? ? "estourou" : "resta #{Interface::Brl.format(left)}"
        "#{index + 1}. #{line.category_name}: #{status} de #{Interface::Brl.format(line.limit)}"
      end

      def history(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        totals = report.months.map(&:total)
        return Interface::ViewMessage.text("Nenhum gasto registrado ainda.") if totals.all?(&:zero?)

        Interface::ViewMessage.image(Interface::ColumnChart.render(totals, labels: report.months.map { |line| line.month.strftime('%m/%y') }),
                                     caption: history_caption(report))
      end

      def history_caption(report)
        lines = ["*Gastos mês a mês*", ""]
        lines += report.months.map do |line|
          "#{line.month.strftime('%m/%Y')}: #{Interface::Brl.format(line.total)}"
        end
        lines.join("\n")
      end

      def category(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        unless report.found?
          return Interface::ViewMessage.text("Categoria não encontrada. Disponíveis: #{report.available_names.join(', ')}")
        end

        lines = ["*#{report.category_name}* — #{report.month.strftime('%m/%Y')}",
                 category_line(report.category_name, report.spent, report.limit)]
        lines << "_Inclui #{Interface::Brl.format(report.subscriptions)} de assinaturas cadastradas._" if report.subscriptions&.positive?
        lines << ""
        lines += report.entries.map { |entry| "· #{entry.date.strftime('%d/%m')} #{Interface::Brl.format(entry.amount)} #{entry.description}" }
        lines << "_Sem lançamentos neste mês._" if report.entries.empty?
        Interface::ViewMessage.text(lines.join("\n"))
      end

      TABLE_HEADER = ["mês".ljust(6), "parcelas".rjust(9), "sobra".rjust(10), "acum.".rjust(11)].join(" ")

      def projection(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report

        lines = ["*Projeção* — #{horizon(report)}", ""]
        lines += monthly_flow(report)
        lines += goals_block(report)
        lines += table_block(report)

        Interface::ViewMessage.new(text: lines.join("\n"),
                                   keyboard: [[["Gráfico do acumulado", "chart:accumulated"]]])
      end

      # O acumulado só vira coluna quando cresce: com sobra negativa não há
      # altura para desenhar, e o texto explica melhor do que uma barra vazia.
      def accumulated_chart(report)
        return Interface::ViewMessage.text("Configuração ainda não concluída. Use /setup.") unless report
        unless report.accumulated.positive?
          return Interface::ViewMessage.text("Nada a acumular: a sobra do mês não é positiva. Use /budgets para ajustar os tetos.")
        end

        Interface::ViewMessage.image(
          Interface::ColumnChart.render(report.lines.map(&:accumulated),
                                        labels: report.lines.map { |line| line.month.strftime("%m/%y") }),
          caption: accumulated_caption(report)
        )
      end

      private

      def horizon(report)
        first, last = report.lines.first.month, report.lines.last.month
        "#{first.strftime('%m/%Y')} a #{last.strftime('%m/%Y')} (#{report.lines.size} meses)"
      end

      def monthly_flow(report)
        lines = ["*Todo mês*",
                 "· entra líquido: #{Interface::Brl.format(report.net_income)}",
                 "· budgets das categorias: −#{Interface::Brl.format(report.budgets)}"]
        lines << "· custos fixos: −#{Interface::Brl.format(report.fixed)}" if report.fixed.positive?
        lines << subscriptions_flow(report)
        lines << "· parcelas: já dentro dos budgets" if report.installments_in_budget?
        lines << "· *sobra livre: #{Interface::Brl.format(report.leftover)}* neste mês"
        lines.compact << ""
      end

      def subscriptions_flow(report)
        return nil unless report.subscriptions.positive?
        return "· assinaturas: #{Interface::Brl.format(report.subscriptions)} já dentro do budget" if report.subscriptions_in_budget?

        "· assinaturas: −#{Interface::Brl.format(report.subscriptions)}"
      end

      def goals_block(report)
        return [] if report.goals.empty?

        lines = ["*Caixinhas* — #{Interface::Brl.format(report.goals_monthly)}/mês para bater os prazos"]
        report.goals.each { |goal| lines += goal_block(goal) }
        lines << slack_line(report) << ""
      end

      def goal_block(goal)
        return ["✅ *#{goal.name}*: completa"] if goal.done?

        pace = goal.monthly.positive? ? "guardar *#{Interface::Brl.format(goal.monthly)}/mês* até #{goal.deadline.strftime('%m/%Y')}" : "sem prazo"
        ["· *#{goal.name}*: faltam #{Interface::Brl.format(goal.missing)} · #{pace}",
         "  #{goal_horizon(goal)}"]
      end

      # Sobra menor que o passo das caixinhas: alguma meta não fecha no prazo, e
      # é melhor dizer de quanto é o buraco do que deixar a conta para o usuário.
      def slack_line(report)
        slack = report.slack
        return "Depois das caixinhas ainda sobram #{Interface::Brl.format(slack)}/mês." unless slack.negative?

        "⚠️ Faltam #{Interface::Brl.format(Domain::Money.zero - slack)}/mês para as caixinhas. Use /budgets para abrir espaço."
      end

      def table_block(report)
        ["*Mês a mês*", "```", TABLE_HEADER, *report.lines.map { |line| table_row(line) }, "```"]
      end

      def table_row(line)
        [line.month.strftime("%m/%y").ljust(6),
         plain(line.installments).rjust(9),
         plain(line.leftover).rjust(10),
         plain(line.accumulated).rjust(11)].join(" ")
      end

      # Na tabela o "R$" repetido só rouba largura.
      def plain(money) = Interface::Brl.format(money).sub("R$ ", "")

      def accumulated_caption(report)
        lines = ["*Acumulado da projeção* — #{horizon(report)}", "",
                 "Sobra livre: #{Interface::Brl.format(report.leftover)}/mês",
                 "Ao fim do horizonte: *#{Interface::Brl.format(report.accumulated)}*"]
        lines << "" << "Caixinhas:" unless report.goals.empty?
        lines += report.goals.map { |goal| goal_forecast(goal) }
        lines.join("\n")
      end

      def subscriptions_note(summary)
        return "assinaturas #{Interface::Brl.format(summary.subscriptions)} (no budget)" if summary.subscriptions_in_budget?

        "assinaturas #{Interface::Brl.format(summary.subscriptions)}"
      end

      public

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

      def goal_forecast(goal) = "#{goal.name}: #{goal_horizon(goal)}"

      # A sobra é dividida entre as caixinhas na ordem dos prazos, então o mês
      # aqui já conta o que as anteriores levaram.
      def goal_horizon(goal)
        return "fora do horizonte da projeção" unless goal.covered_on

        "no ritmo da sobra, fecha em #{goal.covered_on.strftime('%m/%Y')}"
      end

      def goal_line(item)
        pace = item.monthly.positive? ? " · #{Interface::Brl.format(item.monthly)}/mês até #{item.deadline.strftime('%m/%Y')}" : ""
        "· *#{item.name}*: #{Interface::Brl.format(item.saved)} de #{Interface::Brl.format(item.target)}#{pace}"
      end
    end
  end
end
