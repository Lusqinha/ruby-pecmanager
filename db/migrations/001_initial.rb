# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:users) do
      Integer :id, primary_key: true # telegram user id
      String :name
      Integer :salary_cents, null: false, default: 0
      DateTime :setup_done_at
      DateTime :created_at, null: false
    end

    create_table(:categories) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      String :name, null: false
      String :keywords, null: false, default: ""
      String :budget_kind # 'pct' | 'fixed' | nil (no budget set)
      Integer :budget_value, null: false, default: 0
      index %i[user_id name], unique: true
    end

    create_table(:fixed_costs) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      String :name, null: false
      Integer :amount_cents, null: false
      Integer :due_day
    end

    create_table(:subscriptions) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      String :name, null: false
      Integer :amount_cents, null: false
      Integer :due_day
      String :cycle, null: false, default: "monthly" # 'monthly' | 'yearly'
    end

    create_table(:goals) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      String :name, null: false
      Integer :target_cents, null: false
      Integer :saved_cents, null: false, default: 0
      Date :deadline
    end

    create_table(:expenses) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, on_delete: :set_null
      Integer :amount_cents, null: false
      String :description, null: false, default: ""
      Date :spent_on, null: false
      String :source, null: false, default: "manual" # 'llm' | 'regex' | 'manual'
      DateTime :created_at, null: false
      index %i[user_id spent_on]
    end

    create_table(:wizard_states) do
      Integer :user_id, primary_key: true
      String :step, null: false
      String :draft, null: false, default: "{}" # JSON blob, half-finished setup
      DateTime :updated_at, null: false
    end
  end
end
