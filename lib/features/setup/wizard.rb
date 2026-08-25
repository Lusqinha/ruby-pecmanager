# frozen_string_literal: true

module Features
  module Setup
    # Decides the next step and what went wrong, never what to say: the wording
    # lives in the presenter, so the flow can be tested without any text.
    module Wizard
      STEPS = %i[income_type salary deductions categories budgets fixed_costs subscriptions goals confirm].freeze

      Transition = Struct.new(:step, :draft, :status, :error, keyword_init: true) do
        def ok? = status == :ok
        def invalid? = status == :invalid
        def cancelled? = status == :cancelled
        def completed? = status == :completed
      end

      module_function

      def start = transition(:income_type, Draft.new)

      def apply(step:, draft:, input:)
        return transition(step, draft, status: :cancelled) if Input.command?(input, :cancel)
        return back(step, draft) if Input.command?(input, :back)

        case step
        when :income_type then apply_income_type(draft, input)
        when :salary then apply_salary(draft, input)
        when :deductions then apply_collection(:deductions, :categories, draft, input)
        when :categories then apply_categories(draft, input)
        when :budgets then apply_budget(draft, input)
        when :fixed_costs then apply_collection(:fixed_costs, :subscriptions, draft, input)
        when :subscriptions then apply_collection(:subscriptions, :goals, draft, input)
        when :goals then apply_collection(:goals, :confirm, draft, input)
        when :confirm then apply_confirm(draft, input)
        else transition(step, draft, status: :invalid, error: :unknown_step)
        end
      end

      def apply_income_type(draft, input)
        type = %i[pj clt].find { |name| Input.command?(input, name) }
        return invalid(:income_type, draft, :invalid_income_type) unless type

        transition(:salary, draft.with(income_type: type))
      end

      def apply_salary(draft, input)
        return invalid(:salary, draft, :invalid_amount) unless input.is_a?(Input::Amount) && input.money.positive?

        transition(:deductions, draft.with(salary: input.money))
      end

      def apply_categories(draft, input)
        categories =
          if Input.command?(input, :preset) then Presets.categories
          elsif input.is_a?(Input::Categories) then input.items.map { |item| Domain::Category.new(name: item[:name], keywords: item[:keywords].to_a) }
          end

        return invalid(:categories, draft, :no_categories) if categories.nil? || categories.empty?

        transition(:budgets, draft.with(categories: categories, budget_index: 0))
      end

      def apply_budget(draft, input)
        return advance_from_budgets(draft) unless draft.budgets_pending?

        updated =
          case input
          when Input::Percentage then percentage_budget(draft, input.value)
          when Input::Amount then input.money.positive? ? draft.with_budget(Domain::BudgetLimit.fixed(input.money)) : nil
          else Input.command?(input, :skip) ? draft.skipping_budget : nil
          end

        return invalid(:budgets, draft, :invalid_budget) if updated.nil?

        updated.budgets_pending? ? transition(:budgets, updated) : advance_from_budgets(updated)
      end

      def percentage_budget(draft, value)
        return nil unless value.positive? && value <= 100

        draft.with_budget(Domain::BudgetLimit.percent(value))
      end

      def advance_from_budgets(draft) = transition(:fixed_costs, draft)

      # O passo de budgets fica no meio da lista, então voltar do de categorias
      # precisa cair no de deduções, não no loop de budgets.

      def apply_collection(step, next_step, draft, input)
        return transition(next_step, draft) if done?(input)
        return invalid(step, draft, :invalid_items) unless input.is_a?(Input::Items) && input.entities.any?

        transition(step, draft.with(step => draft.public_send(step) + input.entities))
      end

      def apply_confirm(draft, input)
        return transition(:confirm, draft, status: :completed) if Input.command?(input, :confirm)
        return start if Input.command?(input, :restart)

        transition(:confirm, draft)
      end

      def back(step, draft)
        return transition(:budgets, draft.rewind_budget) if step == :budgets && draft.budget_index.positive?

        previous = STEPS[[(STEPS.index(step) || 0) - 1, 0].max]
        previous == :budgets ? transition(:budgets, draft.at_last_category) : transition(previous, draft)
      end

      def done?(input) = Input.command?(input, :done) || Input.command?(input, :skip)

      def transition(step, draft, status: :ok, error: nil)
        Transition.new(step: step, draft: draft, status: status, error: error)
      end

      def invalid(step, draft, error) = transition(step, draft, status: :invalid, error: error)
    end
  end
end
