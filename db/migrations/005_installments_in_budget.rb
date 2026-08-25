# frozen_string_literal: true

Sequel.migration do
  change do
    # Desligado por padrão: parcela é compromisso decidido meses atrás e não
    # disputa o envelope do mês corrente. Quem prefere ver tudo junto liga.
    alter_table(:users) do
      add_column :installments_in_budget, TrueClass, null: false, default: false
    end
  end
end
