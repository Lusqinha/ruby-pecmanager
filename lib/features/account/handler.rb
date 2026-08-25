# frozen_string_literal: true

module Features
  module Account
    class Handler < Shared::Handler
      route(%r{\A/reverter(?:\s+(\d+))?\s*\z}i, to: :preview)
      route "/apagar_tudo", to: :ask_wipe
      callback(/\Arollback:(\d+)\z/, to: :apply)
      callback(/\Awipe:(yes|no)\z/, to: :wipe)

      def initialize(preview_rollback:, apply_rollback:, wipe_account:, presenter:)
        @preview_rollback = preview_rollback
        @apply_rollback = apply_rollback
        @wipe_account = wipe_account
        @presenter = presenter
      end

      def preview(request, minutes = nil)
        @presenter.rollback(@preview_rollback.call(user_id: request.user_id, minutes: minutes))
      end

      def apply(request, since)
        @presenter.rollback(@apply_rollback.call(user_id: request.user_id, since: Time.at(since.to_i)))
      end

      def ask_wipe(_request) = @presenter.confirm_wipe

      def wipe(request, choice)
        return @presenter.wipe(WipeResult.new(status: :kept)) unless choice == "yes"

        @presenter.wipe(@wipe_account.call(user_id: request.user_id))
      end
    end
  end
end
