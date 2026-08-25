# frozen_string_literal: true

module Features
  module Setup
    # Every word the wizard says lives here.
    class Presenter
      ERRORS = {
        invalid_amount: "Não peguei o valor. Manda só o número, tipo `4200` ou `4.200,50`.",
        no_categories: "Manda as categorias separadas por vírgula, ou toca em *Usar o preset*.",
        invalid_budget: "Não entendi. Manda `800` ou `15%` (ou /pular).",
        invalid_items: "Não peguei esse formato.",
        invalid_income_type: "Toca num dos botões: *Sou PJ* ou *Sou CLT*.",
        unknown_step: "Perdi o fio da meada. Manda /setup pra recomeçar."
      }.freeze

      def call(state)
        return Interface::ViewMessage.text("Setup cancelado. Manda /setup quando quiser recomeçar.") if state.cancelled?
        return Interface::ViewMessage.text("Setup salvo. Agora é só mandar os gastos, tipo `35 mercado`.") if state.completed?

        body = state.invalid? ? "#{ERRORS.fetch(state.error, ERRORS[:invalid_items])}\n\n#{prompt(state)}" : "#{collected(state)}#{prompt(state)}"
        Interface::ViewMessage.new(text: body, keyboard: keyboard(state))
      end

      def intro
        "Sou o PecMan. Vamos montar seu controle financeiro em 8 passos rápidos.\n" \
          "A qualquer momento: /voltar, /pular ou /cancelar.\n\n"
      end

      private

      def prompt(state)
        case state.step
        when :income_type then "#{intro}*Passo 1/8 — Como você recebe?*\nIsso muda o que eu pergunto sobre descontos."
        when :salary then salary_prompt(state.draft)
        when :deductions then deductions_prompt(state.draft)
        when :categories then categories_prompt
        when :budgets then budget_prompt(state.draft)
        when :fixed_costs then "*Passo 6/8 — Custos fixos*\nO que sai todo mês da sua conta, um por linha: `aluguel 1200 dia 10`. Sem nenhum? *pronto*."
        when :subscriptions then "*Passo 7/8 — Assinaturas*\nUma por linha: `netflix 39,90 dia 5` ou `dominio 60 anual`. Sem nenhuma? *pronto*."
        when :goals then "*Passo 8/8 — Metas de reserva*\nUma por linha: `reserva 10000 até 12/2027`. Sem nenhuma? *pronto*."
        when :confirm then summary(state)
        else ERRORS[:unknown_step]
        end
      end

      # Passo de coleção repete o mesmo texto a cada linha enviada; sem isto,
      # não dá pra saber se o que você mandou entrou.
      COLLECTIONS = %i[deductions fixed_costs subscriptions goals].freeze

      def collected(state)
        return "" unless COLLECTIONS.include?(state.step)

        items = state.draft.public_send(state.step)
        items.empty? ? "" : "_Anotado até agora: #{items.map(&:name).join(', ')}._\n\n"
      end

      def salary_prompt(draft)
        return "*Passo 2/8 — Receita*\nQuanto você fatura por mês, antes dos impostos?" if draft.pj?

        "*Passo 2/8 — Salário*\nQuanto cai na sua conta por mês?"
      end

      # PJ tem descontos que o próprio usuário calcula todo mês; CLT já recebe
      # líquido, então aqui só entra o que ele quiser acompanhar.
      def deductions_prompt(draft)
        if draft.pj?
          "*Passo 3/8 — Descontos da receita*\nUm por linha, e o percentual sai da receita:\n" \
            "`imposto 6%`\n`inss 178,31`\n`contabilidade 250`\nNão tem? *pronto*."
        else
          "*Passo 3/8 — Descontos*\nSe quiser acompanhar o que sai antes de cair na conta, " \
            "um por linha: `inss 400`, `plano de saúde 180`, `vale 8%`.\nNão quer? *pronto*."
        end
      end

      def categories_prompt
        "*Passo 4/8 — Categorias*\nUsa o preset (#{Features::Setup::Presets.names.join(', ')}) " \
          "ou escreve as suas separadas por vírgula."
      end

      def budget_prompt(draft)
        category = draft.current_category
        return "" unless category

        "*Passo 5/8 — Budgets*\nManda `800` (valor fixo) ou `15%` (do salário). /pular deixa sem limite.\n\n" \
          "Budget de *#{category.name}*? (#{draft.budget_index + 1}/#{draft.categories.size})"
      end

      def keyboard(state)
        case state.step
        when :income_type then [[["Sou PJ", "pj"], ["Sou CLT", "clt"]]]
        when :categories then [[["Usar o preset", "preset"]]]
        when :confirm then [[["Confirmar", "confirmar"], ["Recomeçar", "recomecar"]]]
        end
      end

      def summary(state)
        draft = state.draft
        summary = state.summary
        lines = ["*Confere se está certo:*", "", income_line(draft, summary), "", "*Categorias*"]
        lines += draft.categories.map { |category| category_line(category, summary.salary) }
        lines += section("Descontos", draft.deductions) { |item| "· #{item.name}: #{cost_label(item, draft)}" }
        lines += section("Custos fixos", draft.fixed_costs) { |item| "· #{item.name}: #{Interface::Brl.format(item.amount)}#{due(item)}" }
        lines += section("Assinaturas", draft.subscriptions) { |item| "· #{item.name}: #{Interface::Brl.format(item.amount)}#{item.yearly? ? '/ano' : '/mês'}" }
        lines += section("Metas", draft.goals) { |item| "· #{item.name}: #{Interface::Brl.format(item.target)}#{item.deadline ? " até #{item.deadline.strftime('%m/%Y')}" : ''}" }
        lines += ["", "Sobra depois de fixos, assinaturas e metas: *#{Interface::Brl.format(summary.available)}*",
                  "Soma dos budgets: *#{Interface::Brl.format(summary.committed)}*"]
        lines << "⚠️ Os budgets estouram em *#{Interface::Brl.format(summary.over)}*. Dá pra confirmar assim mesmo e ajustar depois." if summary.over?
        lines << "\nConfirmar?"
        lines.join("\n")
      end

      def income_line(draft, summary)
        gross = draft.salary || Domain::Money.zero
        return "#{draft.pj? ? 'Receita' : 'Salário'}: #{Interface::Brl.format(gross)}" if draft.deductions.empty?

        "#{draft.pj? ? 'Receita' : 'Salário'}: #{Interface::Brl.format(gross)} · " \
          "líquido: *#{Interface::Brl.format(summary.salary)}*"
      end

      def cost_label(item, draft)
        return Interface::Brl.format(item.amount) unless item.percent?

        "#{format('%g', item.amount.cents / 100.0)}% (#{Interface::Brl.format(item.monthly_amount(draft.salary))})"
      end

      def category_line(category, salary)
        label =
          if category.limit.percent? then "#{category.limit.value}% (#{Interface::Brl.format(category.budget_for(salary))})"
          elsif category.limit.fixed? then Interface::Brl.format(category.budget_for(salary))
          else "sem limite"
          end
        "· #{category.name}: #{label}"
      end

      def due(item) = item.due_day ? " (dia #{item.due_day})" : ""

      def section(title, items)
        return [] if items.empty?

        ["", "*#{title}*"] + items.map { |item| yield(item) }
      end
    end
  end
end
