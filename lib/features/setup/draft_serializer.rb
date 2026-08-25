# frozen_string_literal: true

module Features
  module Setup
    # The storage shape belongs to this slice, not to the shared persistence
    # layer: the repository just writes the Hash it gets back.
    module DraftSerializer
      module_function

      def dump(draft)
        {
          income_type: draft.income_type&.to_s,
          deductions: draft.deductions.map { |item| cost(item) },
          salary_cents: draft.salary&.cents,
          budget_index: draft.budget_index,
          categories: draft.categories.map do |category|
            { name: category.name, keywords: category.keywords,
              budget_kind: category.limit.kind&.to_s,
              budget_value: category.limit.fixed? ? category.limit.value.cents : category.limit.value }
          end,
          fixed_costs: draft.fixed_costs.map { |item| cost(item) },
          subscriptions: draft.subscriptions.map do |item|
            { name: item.name, amount_cents: item.amount.cents, due_day: item.due_day, cycle: item.cycle }
          end,
          goals: draft.goals.map do |item|
            { name: item.name, target_cents: item.target.cents, saved_cents: item.saved.cents,
              deadline: item.deadline&.iso8601 }
          end
        }
      end

      def load(data)
        data ||= {}

        Draft.new(
          income_type: data[:income_type]&.to_sym,
          deductions: data[:deductions].to_a.map { |item| load_cost(item) },
          salary: data[:salary_cents] ? Domain::Money.new(data[:salary_cents]) : nil,
          budget_index: data[:budget_index].to_i,
          categories: data[:categories].to_a.map do |item|
            Domain::Category.new(name: item[:name], keywords: item[:keywords].to_a,
                                 limit: limit(item[:budget_kind], item[:budget_value]))
          end,
          fixed_costs: data[:fixed_costs].to_a.map { |item| load_cost(item) },
          subscriptions: data[:subscriptions].to_a.map do |item|
            Domain::Subscription.new(name: item[:name], amount: Domain::Money.new(item[:amount_cents]),
                                     due_day: item[:due_day], cycle: item[:cycle])
          end,
          goals: data[:goals].to_a.map do |item|
            Domain::Goal.new(name: item[:name], target: Domain::Money.new(item[:target_cents]),
                             saved: Domain::Money.new(item[:saved_cents].to_i),
                             deadline: item[:deadline] && Date.parse(item[:deadline]))
          end
        )
      end

      def cost(item)
        { name: item.name, amount_cents: item.amount.cents, due_day: item.due_day,
          kind: item.kind, deduction: item.deduction? }
      end

      def load_cost(item)
        Domain::FixedCost.new(name: item[:name], amount: Domain::Money.new(item[:amount_cents]),
                              due_day: item[:due_day], kind: item[:kind] || Domain::FixedCost::FIXED,
                              deduction: item[:deduction])
      end

      def limit(kind, value)
        case kind&.to_sym
        when Domain::BudgetLimit::PERCENT then Domain::BudgetLimit.percent(value.to_i)
        when Domain::BudgetLimit::FIXED then Domain::BudgetLimit.fixed(Domain::Money.new(value.to_i))
        else Domain::BudgetLimit.none
        end
      end
    end
  end
end
