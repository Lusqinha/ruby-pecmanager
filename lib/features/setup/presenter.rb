# frozen_string_literal: true

module Features
  module Setup
    # Every word the wizard says lives here.
    class Presenter
      ERRORS = {
        invalid_amount: "Valor não reconhecido. Informe apenas o número, como `4200` ou `4.200,50`.",
        no_categories: "Informe as categorias separadas por vírgula, ou use o preset.",
        invalid_budget: "Formato não reconhecido. Informe `800` ou `15%`, ou use /pular.",
        invalid_items: "Formato não reconhecido.",
        invalid_income_type: "Selecione uma das opções: *Sou PJ* ou *Sou CLT*.",
        unknown_step: "Não consegui retomar a configuração. Use /setup para recomeçar."
      }.freeze

      def call(state)
        return Interface::ViewMessage.text("Configuração cancelada. Use /setup quando quiser retomar.") if state.cancelled?
        return Interface::ViewMessage.text("Configuração salva. Envie seus gastos, por exemplo: `35 mercado`.") if state.completed?

        body = state.invalid? ? "#{ERRORS.fetch(state.error, ERRORS[:invalid_items])}\n\n#{prompt(state)}" : "#{collected(state)}#{prompt(state)}"
        Interface::ViewMessage.new(text: body, keyboard: keyboard(state))
      end

      def intro
        "Bem-vindo ao PecMan. A configuração leva 8 passos.\n" \
          "A qualquer momento: /voltar, /pular ou /cancelar.\n\n"
      end

      private

      def prompt(state)
        case state.step
        when :income_type then "#{intro}*Passo 1/8 — Como você recebe?*\nA resposta define quais descontos serão perguntados."
        when :salary then salary_prompt(state.draft)
        when :deductions then deductions_prompt(state.draft)
        when :categories then categories_prompt
        when :budgets then budget_prompt(state.draft)
        when :fixed_costs then "*Passo 6/8 — Custos fixos*\nO que sai todo mês da sua conta, um por linha: `aluguel 1200 dia 10`. Se não houver, envie *pronto*."
        when :subscriptions then "*Passo 7/8 — Assinaturas*\nUma por linha: `netflix 39,90 dia 5` ou `dominio 60 anual`. Se não houver, envie *pronto*."
        when :goals then "*Passo 8/8 — Caixinhas*\nOnde você separa dinheiro, uma por linha: " \
                         "`reserva 10000 até 12/2027` ou `viagem 3000`. Se não houver, envie *pronto*."
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
        items.empty? ? "" : "_Registrado até agora: #{items.map(&:name).join(', ')}._\n\n"
      end

      def salary_prompt(draft)
        return "*Passo 2/8 — Receita*\nQual seu faturamento mensal, antes dos impostos?" if draft.pj?

        "*Passo 2/8 — Salário*\nQuanto você recebe por mês, já líquido?"
      end

      # PJ tem descontos que o próprio usuário calcula todo mês; CLT já recebe
      # líquido, então aqui só entra o que ele quiser acompanhar.
      def deductions_prompt(draft)
        if draft.pj?
          "*Passo 3/8 — Descontos da receita*\nUm por linha. Percentual é calculado sobre o faturamento:\n" \
            "`imposto 6%`\n`inss 178,31`\n`contabilidade 250`\nSe não houver, envie *pronto*."
        else
          "*Passo 3/8 — Descontos*\nSe quiser acompanhar o que é descontado antes do pagamento, " \
            "um por linha: `inss 400`, `plano de saúde 180`, `vale 8%`.\nSe não quiser, envie *pronto*."
        end
      end

      def categories_prompt
        "*Passo 4/8 — Categorias*\nUse o preset (#{Features::Setup::Presets.names.join(', ')}) " \
          "ou informe as suas, separadas por vírgula."
      end

      def budget_prompt(draft)
        category = draft.current_category
        return "" unless category

        "*Passo 5/8 — Budgets*\nInforme `800` (valor fixo) ou `15%` (da renda líquida). /pular deixa sem limite.\n\n" \
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
        lines = ["*Revise a configuração:*", "", income_line(draft, summary), "", "*Categorias*"]
        lines += draft.categories.map { |category| category_line(category, summary.salary) }
        lines += section("Descontos", draft.deductions) { |item| "· #{item.name}: #{cost_label(item, draft)}" }
        lines += section("Custos fixos", draft.fixed_costs) { |item| "· #{item.name}: #{Interface::Brl.format(item.amount)}#{due(item)}" }
        lines += section("Assinaturas", draft.subscriptions) { |item| "· #{item.name}: #{Interface::Brl.format(item.amount)}#{item.yearly? ? '/ano' : '/mês'}" }
        lines += section("Caixinhas", draft.goals) { |item| "· #{item.name}: #{Interface::Brl.format(item.target)}#{item.deadline ? " até #{item.deadline.strftime('%m/%Y')}" : ''}" }
        lines += ["", "Sobra depois de fixos, assinaturas e caixinhas: *#{Interface::Brl.format(summary.available)}*",
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
