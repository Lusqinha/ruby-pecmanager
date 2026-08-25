# frozen_string_literal: true

Sequel.migration do
  change do
    alter_table(:fixed_costs) do
      add_column :kind, String, null: false, default: "fixed" # 'fixed' | 'pct'
      add_column :deduction, TrueClass, null: false, default: false
    end
  end
end
