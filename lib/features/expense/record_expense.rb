# frozen_string_literal: true

module Features
  module Expense
    class RecordExpense
      def initialize(plan_assembler:, expense_repository:, parser:, clock:,
                     deterministic_parser: Infrastructure::Parsing::RegexExpenseParser.new)
        @plan_assembler = plan_assembler
        @expense_repository = expense_repository
        @parser = parser
        @deterministic_parser = deterministic_parser
        @clock = clock
      end

      def call(user_id:, text:)
        _user, plan = @plan_assembler.call(user_id: user_id)
        parsed, category = interpret(text, plan.categories)
        return Result.new(status: :unparseable) unless parsed

        expense = @expense_repository.add(build(user_id, parsed, category))

        return Result.new(status: :needs_category, expense: expense, categories: plan.categories) unless category

        Support.recorded(expense, category, @expense_repository, plan)
      end

      private

      # O regex resolve sozinho quando a categoria sai da descrição. O modelo só
      # entra quando ela não sai — e depois que o usuário corrige uma vez, a
      # keyword aprendida faz o regex acertar sozinho nas próximas.
      def interpret(text, categories)
        parsed = @deterministic_parser.parse(text, today: @clock.today)
        category = parsed && Domain::Categorizer.resolve(categories, parsed.category_hint)
        return [parsed, category] if category

        from_llm = @parser.parse(text, today: @clock.today, categories: hints(categories))
        return [parsed, nil] unless from_llm

        [from_llm, Domain::Categorizer.resolve(categories, from_llm.category_hint)]
      end

      # O modelo é pequeno: só os nomes não bastam para ele escolher. As
      # keywords, que crescem a cada correção do usuário, dão o contexto.
      def hints(categories)
        categories.map do |category|
          words = category.keywords.first(6)
          words.empty? ? category.name : "#{category.name} (#{words.join(', ')})"
        end
      end

      def build(user_id, parsed, category)
        Domain::Expense.new(
          user_id: user_id, category_id: category&.id, amount: parsed.amount,
          description: parsed.description.to_s[0, 120], spent_on: parsed.spent_on,
          source: parsed.source, created_at: @clock.now
        )
      end
    end

    # Shared by the use cases that answer with a booking plus its budget status.
    module Support
      module_function

      def recorded(expense, category, expense_repository, plan)
        totals = expense_repository.totals_by_category(expense.user_id, Domain::Month.range(expense.spent_on))
        spent = plan.spent_for(category, totals)
        limit = category.budget_for(plan.net_income)

        Result.new(status: :recorded, expense: expense, category: category, spent_in_month: spent, limit: limit,
                   moves: rebalance(plan, category, spent, limit, totals))
      end

      # Estourou o teto: em vez de só avisar, diz de onde tirar a cota — o mês
      # inteiro continua cabendo no mesmo dinheiro.
      def rebalance(plan, category, spent, limit, totals)
        return [] if limit.zero? || spent <= limit

        slots = plan.categories.map do |item|
          Domain::Rebalance::Slot.new(name: item.name, limit: item.budget_for(plan.net_income),
                                      spent: plan.spent_for(item, totals))
        end

        Domain::Rebalance.moves(spent - limit, slots, to: category.name)
      end
    end
  end
end
