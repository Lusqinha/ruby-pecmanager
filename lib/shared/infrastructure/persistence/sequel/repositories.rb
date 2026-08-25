# frozen_string_literal: true

require "sequel"
require "json"

module Infrastructure
  module Persistence
    # Plain datasets, no ORM models: entities are built by the mappers at this
    # boundary, so nothing Sequel escapes the adapter.
    module SequelStore
      class Repository
        def initialize(db)
          @db = db
        end

        private

        attr_reader :db
      end

      class UserRepository < Repository
        def find(id) = Mappers.user(db[:users][id: id])

        def save(user)
          row = { name: user.name, salary_cents: user.salary.cents, setup_done_at: user.setup_done_at,
                  installments_in_budget: user.installments_in_budget? }
          existing = db[:users].where(id: user.id)
          existing.any? ? existing.update(row) : db[:users].insert(row.merge(id: user.id, created_at: Time.now))
          find(user.id)
        end
      end

      class CategoryRepository < Repository
        def for_user(user_id)
          db[:categories].where(user_id: user_id).order(:id).map { |row| Mappers.category(row) }
        end

        def find(user_id, id)
          row = db[:categories][user_id: user_id, id: id]
          row && Mappers.category(row)
        end

        def save(category)
          db[:categories].where(id: category.id).update(Mappers.category_row(category, category.user_id))
          find(category.user_id, category.id)
        end

        # Categories in keep_ids stay even when the new plan drops them, so their
        # expenses keep a name.
        def replace_all(user_id, categories, keep_ids: [])
          existing = for_user(user_id)
          wanted = categories.map(&:name)

          existing.each do |category|
            next if wanted.any? { |name| name.casecmp?(category.name) }
            next if keep_ids.include?(category.id)

            db[:categories].where(id: category.id).delete
          end

          categories.each { |category| upsert(user_id, existing, category) }
          for_user(user_id)
        end

        private

        def upsert(user_id, existing, category)
          row = Mappers.category_row(category, user_id)
          match = existing.find { |item| item.name.casecmp?(category.name) }
          if match
            db[:categories].where(id: match.id).update(row.reject { |key, _| key == :keywords })
          else
            db[:categories].insert(row)
          end
        end
      end

      class PendingImportRepository < Repository
        def find(user_id) = db[:pending_imports][user_id: user_id]&.fetch(:payload)

        def save(user_id, payload)
          row = { user_id: user_id, payload: payload, created_at: Time.now }
          existing = db[:pending_imports].where(user_id: user_id)
          existing.any? ? existing.update(row) : db[:pending_imports].insert(row)
          payload
        end

        def delete(user_id) = db[:pending_imports].where(user_id: user_id).delete
      end

      class InstallmentPlanRepository < Repository
        def for_user(user_id)
          db[:installment_plans].where(user_id: user_id).order(:id).map { |row| Mappers.installment_plan(row) }
        end

        # Filtra em Ruby: quem sabe se a parcela cai no mês é a entidade, e a
        # regra de corte por cancelamento não cabe num WHERE sem duplicá-la.
        def active(user_id, month)
          for_user(user_id).select { |plan| plan.active_in?(month) }
        end

        def find(user_id, id)
          Mappers.installment_plan(db[:installment_plans][user_id: user_id, id: id])
        end

        def add(plan)
          id = db[:installment_plans].insert(
            Mappers.installment_plan_row(plan, plan.user_id).merge(created_at: Time.now)
          )
          find(plan.user_id, id)
        end

        def save(plan)
          db[:installment_plans].where(id: plan.id, user_id: plan.user_id)
                                .update(Mappers.installment_plan_row(plan, plan.user_id))
          find(plan.user_id, plan.id)
        end
      end

      class ExpenseRepository < Repository
        def add(expense)
          id = db[:expenses].insert(Mappers.expense_row(expense))
          find(expense.user_id, id)
        end

        def save(expense)
          db[:expenses].where(id: expense.id).update(Mappers.expense_row(expense))
          find(expense.user_id, expense.id)
        end

        def find(user_id, id)
          row = db[:expenses][user_id: user_id, id: id]
          row && Mappers.expense(row)
        end

        def delete(user_id, id) = db[:expenses].where(user_id: user_id, id: id).delete

        def last_for(user_id)
          row = db[:expenses].where(user_id: user_id).order(Sequel.desc(:id)).first
          row && Mappers.expense(row)
        end

        def for_period(user_id, range)
          db[:expenses].where(user_id: user_id, spent_on: range).order(:id).map { |row| Mappers.expense(row) }
        end

        def for_category(user_id, category_id, range)
          db[:expenses].where(user_id: user_id, category_id: category_id, spent_on: range)
                       .order(:id).map { |row| Mappers.expense(row) }
        end

        def totals_by_category(user_id, range)
          db[:expenses].where(user_id: user_id, spent_on: range)
                       .group(:category_id)
                       .select_hash(:category_id, Sequel.function(:sum, :amount_cents).as(:total))
                       .transform_values { |cents| Domain::Money.new(cents.to_i) }
        end

        def category_ids_with_expenses(user_id)
          db[:expenses].where(user_id: user_id).exclude(category_id: nil).distinct.select_map(:category_id)
        end
      end

      class CollectionRepository < Repository
        def for_user(user_id)
          db[table].where(user_id: user_id).order(:id).map { |row| Mappers.public_send(mapper, row) }
        end

        # A filtered dataset scopes the delete but not the insert, so user_id
        # goes in explicitly.
        def replace_all(user_id, items)
          db[table].where(user_id: user_id).delete
          items.each { |item| db[table].insert(Mappers.public_send(:"#{mapper}_row", item, user_id)) }
          for_user(user_id)
        end
      end

      class FixedCostRepository < CollectionRepository
        def table = :fixed_costs
        def mapper = :fixed_cost
      end

      class SubscriptionRepository < CollectionRepository
        def table = :subscriptions
        def mapper = :subscription
      end

      class GoalRepository < CollectionRepository
        def table = :goals
        def mapper = :goal
      end

      # Stored as JSON so an abandoned wizard never writes into the real tables.
      # The shape is injected as a serializer, so this stays slice-agnostic.
      class DraftRepository < Repository
        def initialize(db, serializer:)
          super(db)
          @serializer = serializer
        end

        def find(user_id)
          row = db[:wizard_states][user_id: user_id]
          return nil unless row

          data = JSON.parse(row[:draft].to_s.empty? ? "{}" : row[:draft], symbolize_names: true)
          { step: row[:step].to_sym, draft: @serializer.load(data) }
        end

        def save(user_id, step, draft)
          row = { step: step.to_s, draft: JSON.generate(@serializer.dump(draft)), updated_at: Time.now }
          existing = db[:wizard_states].where(user_id: user_id)
          existing.any? ? existing.update(row) : db[:wizard_states].insert(row.merge(user_id: user_id))
          find(user_id)
        end

        def delete(user_id) = db[:wizard_states].where(user_id: user_id).delete
      end
    end
  end
end
