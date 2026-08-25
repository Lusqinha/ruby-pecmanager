# frozen_string_literal: true

module Features
  module Installments
    class RecordInstallment
      def initialize(category_repository:, installment_repository:, parser:, clock:, user_repository:)
        @user_repository = user_repository
        @category_repository = category_repository
        @installment_repository = installment_repository
        @parser = parser
        @clock = clock
      end

      def call(user_id:, text:)
        parsed = TextInput.parse(text, today: @clock.today)
        return Result.new(status: :invalid) unless parsed

        category = categorize?(user_id) ? resolve(parsed[:description], @category_repository.for_user(user_id), text) : nil
        plan = @installment_repository.add(build(user_id, parsed, category))

        Result.new(status: :recorded, plan: plan, category: category, month: @clock.today)
      end

      private

      # Parcela fora do budget não entra em nenhuma linha de categoria, então
      # categorizar seria trabalho jogado fora — inclusive uma ida ao modelo.
      def categorize?(user_id) = @user_repository.find(user_id)&.installments_in_budget?

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
          total: parsed[:total], count: parsed[:count], first_month: parsed[:first_month],
          created_at: @clock.now
        )
      end
    end
  end
end
