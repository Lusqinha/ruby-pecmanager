# frozen_string_literal: true

Sequel.migration do
  change do
    # Um import aberto por usuário: o resumo espera a confirmação, e o próximo
    # import substitui o anterior.
    create_table(:pending_imports) do
      Integer :user_id, primary_key: true
      String :payload, null: false, text: true
      DateTime :created_at, null: false
    end
  end
end
