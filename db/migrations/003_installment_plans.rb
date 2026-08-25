# frozen_string_literal: true

Sequel.migration do
  change do
    create_table(:installment_plans) do
      primary_key :id
      foreign_key :user_id, :users, null: false, on_delete: :cascade
      foreign_key :category_id, :categories, on_delete: :set_null
      String :description, null: false
      String :origin
      Integer :total_cents, null: false
      Integer :count, null: false
      Date :first_month, null: false # sempre dia 1
      Date :cancelled_on
      DateTime :created_at, null: false
      index %i[user_id first_month]
    end
  end
end
