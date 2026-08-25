# frozen_string_literal: true

Sequel.migration do
  change do
    # Registro do que já foi enviado automaticamente, para que reiniciar o bot
    # dentro da janela não mande o mesmo relatório duas vezes.
    create_table(:deliveries) do
      Integer :user_id, null: false
      String :kind, null: false
      Date :sent_on, null: false
      primary_key %i[user_id kind]
    end
  end
end
