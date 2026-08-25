# frozen_string_literal: true

require "json"
require "date"

module Infrastructure
  module Persistence
    module SequelStore
      # The only place that knows both the row and the entity shape.
      module Mappers
        module_function

        def user(row)
          return nil unless row

          Domain::User.new(id: row[:id], name: row[:name], salary: Domain::Money.new(row[:salary_cents].to_i),
                           setup_done_at: row[:setup_done_at],
                           installments_in_budget: row[:installments_in_budget])
        end

        def category(row)
          Domain::Category.new(
            id: row[:id], user_id: row[:user_id], name: row[:name],
            keywords: row[:keywords].to_s.split(","),
            limit: limit(row[:budget_kind], row[:budget_value])
          )
        end

        def limit(kind, value)
          case kind&.to_sym
          when Domain::BudgetLimit::PERCENT then Domain::BudgetLimit.percent(value.to_i)
          when Domain::BudgetLimit::FIXED then Domain::BudgetLimit.fixed(Domain::Money.new(value.to_i))
          else Domain::BudgetLimit.none
          end
        end

        def category_row(category, user_id)
          kind = category.limit.kind
          value = category.limit.fixed? ? category.limit.value.cents : category.limit.value.to_i
          { user_id: user_id, name: category.name, keywords: category.keywords.join(","),
            budget_kind: kind&.to_s, budget_value: value }
        end

        def installment_plan(row)
          return nil unless row

          Domain::InstallmentPlan.new(
            id: row[:id], user_id: row[:user_id], category_id: row[:category_id],
            description: row[:description], origin: row[:origin],
            total: Domain::Money.new(row[:total_cents].to_i), count: row[:count].to_i,
            first_month: row[:first_month], cancelled_on: row[:cancelled_on], created_at: row[:created_at]
          )
        end

        def installment_plan_row(plan, user_id)
          { user_id: user_id, category_id: plan.category_id, description: plan.description,
            origin: plan.origin, total_cents: plan.total.cents, count: plan.count,
            first_month: plan.first_month, cancelled_on: plan.cancelled_on }
        end

        def fixed_cost(row)
          Domain::FixedCost.new(id: row[:id], user_id: row[:user_id], name: row[:name],
                                amount: Domain::Money.new(row[:amount_cents].to_i), due_day: row[:due_day],
                                kind: row[:kind] || Domain::FixedCost::FIXED, deduction: row[:deduction])
        end

        def fixed_cost_row(item, user_id)
          { user_id: user_id, name: item.name, amount_cents: item.amount.cents, due_day: item.due_day,
            kind: item.kind, deduction: item.deduction? }
        end

        def subscription(row)
          Domain::Subscription.new(id: row[:id], user_id: row[:user_id], name: row[:name],
                                   amount: Domain::Money.new(row[:amount_cents].to_i),
                                   due_day: row[:due_day], cycle: row[:cycle])
        end

        def subscription_row(item, user_id)
          { user_id: user_id, name: item.name, amount_cents: item.amount.cents,
            due_day: item.due_day, cycle: item.cycle }
        end

        def goal(row)
          Domain::Goal.new(id: row[:id], user_id: row[:user_id], name: row[:name],
                           target: Domain::Money.new(row[:target_cents].to_i),
                           saved: Domain::Money.new(row[:saved_cents].to_i), deadline: row[:deadline])
        end

        def goal_row(item, user_id)
          { user_id: user_id, name: item.name, target_cents: item.target.cents,
            saved_cents: item.saved.cents, deadline: item.deadline }
        end

        def expense(row)
          Domain::Expense.new(id: row[:id], user_id: row[:user_id], category_id: row[:category_id],
                              amount: Domain::Money.new(row[:amount_cents].to_i), description: row[:description],
                              spent_on: row[:spent_on], source: row[:source], created_at: row[:created_at])
        end

        def expense_row(expense)
          { user_id: expense.user_id, category_id: expense.category_id, amount_cents: expense.amount.cents,
            description: expense.description, spent_on: expense.spent_on, source: expense.source,
            created_at: expense.created_at || Time.now }
        end

      end
    end
  end
end
