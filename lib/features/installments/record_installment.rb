# frozen_string_literal: true

module Features
  module Installments
    class RecordInstallment
      def initialize(category_repository:, installment_repository:, parser:, clock:)
        @category_repository = category_repository
        @installment_repository = installment_repository
        @parser = parser
        @clock = clock
      end

      def call(user_id:, text:)
        parsed = TextInput.parse(text, today: @clock.today)
        return Result.new(status: :invalid) unless parsed

        categories = @category_repository.for_user(user_id)
        category = resolve(parsed[:description], categories, text)
        plan = @installment_repository.add(build(user_id, parsed, category))

        Result.new(status: :recorded, plan: plan, category: category, month: @clock.today)
      end

      private

      # Mesma escada do gasto: determinístico primeiro, modelo só quando a
      # descrição não diz nada ao Categorizer.
      def resolve(description, categories, text)
        category = Domain::Categorizer.resolve(categories, description)
        return category if category

        parsed = @parser.parse(text, today: @clock.today, categories: hints(categories))
        parsed && Domain::Categorizer.resolve(categories, parsed.category_hint)
      end

      def hints(categories)
        categories.map do |category|
          words = category.keywords.first(6)
          words.empty? ? category.name : "#{category.name} (#{words.join(', ')})"
        end
      end

      def build(user_id, parsed, category)
        Domain::InstallmentPlan.new(
          user_id: user_id, category_id: category&.id, description: parsed[:description][0, 120],
          total: parsed[:total], count: parsed[:count], first_month: parsed[:first_month]
        )
      end
    end
  end
end
