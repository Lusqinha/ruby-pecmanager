# frozen_string_literal: true

module Features
  module Account
    # Apaga o usuário e tudo que pende dele. As tabelas estão em cascade, então
    # o que precisa de tiro próprio é o que não tem chave estrangeira.
    class WipeAccount
      def initialize(user_repository:, draft_repository:, pending_repository:)
        @user_repository = user_repository
        @draft_repository = draft_repository
        @pending_repository = pending_repository
      end

      def call(user_id:)
        @draft_repository.delete(user_id)
        @pending_repository.delete(user_id)
        @user_repository.delete(user_id)

        WipeResult.new(status: :wiped)
      end
    end
  end
end
