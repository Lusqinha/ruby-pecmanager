# frozen_string_literal: true

module Features
  module Expense
    class RecordExpense
      def initialize(user_repository:, category_repository:, expense_repository:, parser:, clock:,
                     fixed_cost_repository:,
                     deterministic_parser: Infrastructure::Parsing::RegexExpenseParser.new)
        @fixed_cost_repository = fixed_cost_repository
        @user_repository = user_repository
        @category_repository = category_repository
        @expense_repository = expense_repository
        @parser = parser
        @deterministic_parser = deterministic_parser
        @clock = clock
      end

      def call(user_id:, text:)
        categories = @category_repository.for_user(user_id)
        parsed, category = interpret(text, categories)
        return Result.new(status: :unparseable) unless parsed

        expense = @expense_repository.add(build(user_id, parsed, category))

        return Result.new(status: :needs_category, expense: expense, categories: categories) unless category

        user = @user_repository.find(user_id)
        Support.recorded(expense, category, @expense_repository, user, Support.net_income(user, @fixed_cost_repository))
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

      def net_income(user, fixed_cost_repository)
        Domain::NetIncome.of(user.salary, fixed_cost_repository.for_user(user.id))
      end

      def recorded(expense, category, expense_repository, user, net_income)
        spent = expense_repository.for_category(user.id, category.id, Domain::Month.range(expense.spent_on))
                                  .reduce(Domain::Money.zero) { |total, item| total + item.amount }

        Result.new(status: :recorded, expense: expense, category: category,
                   spent_in_month: spent, limit: category.budget_for(net_income))
      end
    end
  end
end
