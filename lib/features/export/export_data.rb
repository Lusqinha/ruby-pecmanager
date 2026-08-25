# frozen_string_literal: true

module Features
  module Export
    # Um retrato do plano e dos gastos para outra ferramenta ler. Só leitura:
    # nada aqui muda o estado do usuário.
    class ExportData
      MONTHS = 6

      def initialize(plan_assembler:, expense_repository:, installment_repository:, clock:)
        @plan_assembler = plan_assembler
        @expense_repository = expense_repository
        @installment_repository = installment_repository
        @clock = clock
      end

      def call(user_id:, months: MONTHS)
        user, plan = @plan_assembler.call(user_id: user_id)
        return Result.new(status: :no_plan) unless user

        today = @clock.today
        summary = plan.summary(today)
        names = plan.categories.to_h { |category| [category.id, category.name] }

        Result.new(status: :ready, generated_on: today, data: {
                     gerado_em: today.iso8601, moeda: "BRL", mes_atual: today.strftime("%Y-%m"),
                     renda: income(plan, summary),
                     categorias: categories(user_id, plan, today),
                     custos_fixos: fixed_costs(plan),
                     assinaturas: subscriptions(plan),
                     caixinhas: goals(plan, today),
                     parcelamentos: installments(user_id, today),
                     lancamentos: expenses(user_id, today, months, names)
                   })
      end

      private

      def income(plan, summary)
        { salario_bruto: brl(plan.salary), deducoes: brl(plan.deductions), liquido: brl(plan.net_income),
          custos_fixos: brl(summary.fixed_costs), assinaturas: brl(summary.subscriptions),
          assinaturas_dentro_do_budget: summary.subscriptions_in_budget?,
          caixinhas_por_mes: brl(summary.goals), budgets: brl(summary.committed),
          disponivel_para_budgets: brl(summary.available), livre: brl(summary.free) }
      end

      def categories(user_id, plan, today)
        totals = @expense_repository.totals_by_category(user_id, Domain::Month.range(today))
        plan.categories.map do |category|
          limit = category.budget_for(plan.net_income)
          spent = plan.spent_for(category, totals)
          { nome: category.name, tipo_do_teto: category.limit.kind&.to_s || "sem_limite",
            teto: brl(limit), gasto_no_mes: brl(spent), restante: brl([limit - spent, Domain::Money.zero].max),
            palavras_chave: category.keywords }
        end
      end

      def fixed_costs(plan)
        plan.fixed_costs.map do |cost|
          { nome: cost.name, valor_mensal: brl(cost.monthly_amount(plan.salary)),
            percentual: cost.percent?, desconto_na_folha: cost.deduction?, dia: cost.due_day }
        end
      end

      def subscriptions(plan)
        plan.subscriptions.map do |item|
          { nome: item.name, valor: brl(item.amount), ciclo: item.cycle,
            valor_mensal: brl(item.monthly_amount), dia: item.due_day }
        end
      end

      def goals(plan, today)
        plan.goals.map do |goal|
          { nome: goal.name, guardado: brl(goal.saved), meta: brl(goal.target), falta: brl(goal.missing),
            prazo: goal.deadline&.iso8601, precisa_por_mes: brl(goal.monthly_contribution(today)),
            meses_ate_o_prazo: goal.deadline ? goal.months_until(today) : nil }
        end
      end

      def installments(user_id, today)
        @installment_repository.active(user_id, today).map do |plan|
          { descricao: plan.description, parcela: brl(plan.due_in(today)), posicao: plan.label_in(today),
            ultimo_mes: plan.last_month&.strftime("%Y-%m"), origem: plan.origin }
        end
      end

      def expenses(user_id, today, months, names)
        first = Domain::Month.range(Domain::Month.advance(today, -(months - 1))).first

        @expense_repository.for_period(user_id, first..Domain::Month.range(today).last).map do |expense|
          { data: expense.spent_on.iso8601, valor: brl(expense.amount), descricao: expense.description,
            categoria: names[expense.category_id] }
        end
      end

      def brl(money) = (money.cents / 100.0).round(2)
    end
  end
end
